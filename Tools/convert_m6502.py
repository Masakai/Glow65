#!/usr/bin/env python3
"""Microsoft BASIC for 6502 v1.1 (MACRO-10 構文)を ca65 構文へ変換する。

入力: ROM/basic/upstream/m6502.asm(Microsoft, MIT License)
出力: ROM/basic/build/m6502.s

方針:
- 設定は OSI(REALIO=2)を基にし、本ボードに合わせて PATCHES で定数を差し替える。
- 条件コンパイル(IFE/IFN)とマクロ(DEFINE)は ca65 の .if / .macro へ構造的に変換する。
- 変換できなかった行は例外にせず、`; !! 未変換:` として出力に残す(後で人が確認する)。
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "ROM/basic/upstream/m6502.asm"
OUT = ROOT / "ROM/basic/build/m6502.s"

# --- 本ボード向けの差し替え(元の文 → 差し替え後の文)。キーは空白を詰めた文字列 ---
# アドレスは 10 進。UART は $A000(状態)/$A001(データ)、モニタの入出力は $F000/$F003。
UART_STATUS = 0xA000
UART_DATA = 0xA001
MON_CHROUT = 0xF003
PATCHES = {
    "LNGERR==0": "LNGERR==1",  # 長いエラーメッセージ(ROM に余裕があるため)
    # 起動バナーの機種名(OSI は別の機種名なので差し替える。原典の COPYRIGHT 行は残る)
    'DT"OSI6502BASICVERSION1.1"': 'DT"GLOW65 BASIC  (MICROSOFT BASIC V1.1 FOR 6502)"',
    "REALIO=4": "REALIO=2",  # OSI 構成(6850 系 ACIA、RORSW=0、トリゴノメトリ関数あり)を基にする
    "ROMLOC=^O20000": f"ROMLOC=49152",  # BASIC ROM は $C000 から
    "RAMLOC==^O100000": "RAMLOC==1024",  # BASIC プログラム領域は $0400 から
    "OUTCH==^O177013": f"OUTCH=={MON_CHROUT}",
    "LDA^O176000": f"LDA {UART_STATUS}",  # OSI の ACIA 状態レジスタ
    "LDA^O176001": f"LDA {UART_DATA}",  # OSI の ACIA データレジスタ
}

# --- 変換後のアセンブリへの追加(原典にない動作)。キーは変換後の文、値は差し替え後 ---
# 行の入力を、予約語に変換する前に大文字にする。引用符の中、REM、DATA は、この手前で
# 取り除かれるので、文字列の中の小文字は、そのまま残る。
POST_PATCHES = {
    "MUSTCR:\n    sty BUFPTR\n": (
        "MUSTCR:\n"
        "    cmp #'a'\n"
        "    bcc @upper_done\n"
        "    cmp #'z'+1\n"
        "    bcs @upper_done\n"
        "    and #$DF\n"
        "    sta BUFOFS,X\n"
        "@upper_done:\n"
        "    sty BUFPTR\n"
    ),
    # 予約語の2文字目以降も、比べるときだけ大文字にする(バッファは書き換えない)
    "RESCON:\n    lda BUFOFS,X\n": (
        "RESCON:\n"
        "    lda BUFOFS,X\n"
        "    cmp #'a'\n"
        "    bcc @compare_upper\n"
        "    cmp #'z'+1\n"
        "    bcs @compare_upper\n"
        "    and #$DF\n"
        "@compare_upper:\n"
    ),
}

MNEMONICS = set(
    "ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV CMP CPX CPY "
    "DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA PHP PLA PLP ROL "
    "ROR RTI RTS SBC SEC SED SEI STA STX STY TAX TAY TSX TXA TXS TYA".split()
)
# ca65 側の prelude.inc で定義するマクロ(元ソースが SEARCH M6502 で読み込むライブラリ相当)
LIBRARY_MACROS = set(
    "LDAI LDXI LDYI CMPI CPXI CPYI ADCI SBCI ANDI ORAI EORI "
    "LDADY STADY CMPDY ADCDY SBCDY JMPD TJSR".split()
)
BLOCK_RE = re.compile(r"^\s*(?:([A-Za-z_$.%][A-Za-z0-9_$.%]*)\s*::?\s*)?(IFE|IFN|IFDEF|IFNDEF|IFDIF|REPEAT|DEFINE|IRPC|IF1|IF2)\b", re.I)


# ---------------------------------------------------------------- 前処理 ----
def strip_comment_blocks(text):
    """`COMMENT <区切り> ... <区切り>` を取り除く。"""
    out = []
    i = 0
    pat = re.compile(r"^[ \t]*COMMENT[ \t]+(\S)", re.M)
    while True:
        m = pat.search(text, i)
        if not m:
            out.append(text[i:])
            break
        out.append(text[i:m.start()])
        delim = m.group(1)
        end = text.find(delim, m.end())
        if end < 0:
            break
        i = end + 1
    return "".join(out)


def strip_line_comments(text):
    lines = []
    for line in text.split("\n"):
        quoted = False
        cut = len(line)
        for k, c in enumerate(line):
            if c == '"':
                quoted = not quoted
            elif c == ";" and not quoted:
                cut = k
                break
        lines.append(line[:cut].rstrip())
    return "\n".join(lines)


# ---------------------------------------------------------------- 構文解析 ----
def parse(s, i, in_block):
    """文のリスト(('stmt', 文字列) | ('block', ヘッダ, 子))を返す。"""
    nodes = []
    buf = []
    depth = 0

    def flush():
        t = "".join(buf).strip()
        buf.clear()
        if t:
            nodes.append(("stmt", t))

    while i < len(s):
        c = s[i]
        if c == '"':
            j = s.find('"', i + 1)
            nl = s.find("\n", i + 1)
            if j < 0 or (0 <= nl < j):
                buf.append(c)
                i += 1
                continue
            buf.append(s[i:j + 1])
            i = j + 1
            continue
        if c == "\n":
            if depth == 0:
                flush()
            else:
                buf.append(" ")
            i += 1
            continue
        if c == "<":
            t = "".join(buf)
            bm = BLOCK_RE.match(t)
            if depth == 0 and bm and t.rstrip().endswith(","):
                header = t.strip()
                buf.clear()
                if bm.group(1):  # `LABEL: IFE ...,<` の形: ラベルを先に出す
                    nodes.append(("stmt", bm.group(1) + ":"))
                    header = t[bm.start(2):].strip()
                body, i = parse(s, i + 1, True)
                nodes.append(("block", header, body))
                continue
            depth += 1
            buf.append("(")
            i += 1
            continue
        if c == ">":
            if depth > 0:
                depth -= 1
                buf.append(")")
                i += 1
                continue
            flush()
            if not in_block:
                raise SyntaxError("対応しない '>' (位置 %d)" % i)
            return nodes, i + 1
        buf.append(c)
        i += 1
    flush()
    return nodes, i


# ---------------------------------------------------------------- 式の変換 ----
class Ctx:
    def __init__(self):
        self.radix = 10
        self.macros = set()  # DEFINE されたマクロ名
        self.unconverted = 0
        self.stop = False
        self.in_define = False
        self.consts = set()  # 数値だけから成る(.set で再定義できる)シンボル


NUM_RE = re.compile(r"(?<![A-Za-z0-9_$.%@\x01])(\d+)(?![A-Za-z0-9_$%@\x02])")
IDENT = r"[A-Za-z_$.%][A-Za-z0-9_$.%]*"


def conv_expr(e, ctx):
    e = e.strip()
    e = re.sub(r"\^O([0-7]+)", lambda m: "\x01%d\x02" % int(m.group(1), 8), e)
    e = re.sub(r"\^D([0-9]+)", lambda m: "\x01%d\x02" % int(m.group(1), 10), e)
    e = re.sub(r"\^B([01]+)", lambda m: "\x01%d\x02" % int(m.group(1), 2), e)
    # 文字定数 "c" → ASCII コード(数値変換の対象外にするため印を付ける)
    e = re.sub(r'"(.)"', lambda m: "\x01%d\x02" % ord(m.group(1)), e)

    def num(m):
        t = m.group(1)
        # MACRO-10 は RADIX 8 でも 8 や 9 を含む数を10進として扱う
        if ctx.radix == 8 and "8" not in t and "9" not in t:
            return str(int(t, 8))
        return str(int(t, 10))

    e = NUM_RE.sub(num, e)
    e = e.replace("\x01", "").replace("\x02", "")
    e = e.replace("!", "|")
    # 現在位置 `.` → `*`
    e = re.sub(r"(?<![A-Za-z0-9_$.%])\.(?![A-Za-z0-9_$%])", "*", e)
    e = trunc_symbols(e)
    e = e.replace("%Q", "Q__local")
    return e


SYM_RE = re.compile(r"(?<![A-Za-z0-9_$.%@\x01])[A-Za-z][A-Za-z0-9_$.%]*")


def trunc6(name):
    """MACRO-10 ではシンボルの先頭6文字だけが有効。"""
    return name[:6] if len(name) > 6 else name


def trunc_symbols(e):
    return SYM_RE.sub(lambda m: trunc6(m.group(0)), e)


def conv_operand(op, ctx):
    op = op.strip()
    while op.endswith(","):
        op = op[:-1].rstrip()
    if not op:
        return ""
    return conv_expr(op, ctx)


# ---------------------------------------------------------------- 文の変換 ----
def conv_string_bytes(arg):
    """`"ABC"` → ('.byte "AB", 'C'|$80')(最終文字の最上位ビットを立てる)。"""
    body = arg[1:-1]
    if not body:
        return ""
    head, last = body[:-1], body[-1]
    parts = []
    if head:
        parts.append('"%s"' % head)
    parts.append("%d" % (ord(last) | 0x80))
    return ".byte " + ", ".join(parts)


def conv_stmt(s, ctx, out):
    s = s.strip()
    if not s:
        return
    squeezed = re.sub(r"\s+", "", s)
    if squeezed in PATCHES:
        s = PATCHES[squeezed]

    # ラベル(複数可)
    while True:
        m = re.match(r"^(%s)\s*(::?)(?!=)" % IDENT, s)
        if not m:
            break
        name = m.group(1)
        if trunc6(name.upper()) == "LASTWR":
            ctx.stop = True
            return
        if trunc6(name.upper()) == "FBUFFR":
            out.append('.segment "PAGE1"')
            out.append(".org $0100")
        if name == "$Z":
            s = s[m.end():].strip()
            continue
        label = trunc6(name).replace("%Q", "Q__local")
        out.append("%s:" % label)
        s = s[m.end():].strip()
    if not s:
        return

    # 代入 NAME == expr / NAME = expr
    m = re.match(r"^(%s)\s*==?\s*(.*)$" % IDENT, s)
    if m and m.group(1).upper() not in MNEMONICS and m.group(1).upper() != "EXP":
        name, value = trunc6(m.group(1)), m.group(2)
        expr = conv_expr(value, ctx)
        idents = re.findall(r"(?<![0-9A-Za-z_$])[A-Za-z_][A-Za-z0-9_$]*", expr)
        if all(i.upper() in ctx.consts or i == "*" for i in idents) and "*" not in expr:
            out.append("%s .set %s" % (name, expr))
            ctx.consts.add(name.upper())
        else:
            out.append("%s = %s" % (name, expr))
        return

    m = re.match(r"^([A-Za-z_$.%][A-Za-z0-9_$.%]*)\s*(.*)$", s)
    if not m:
        # 先頭が識別子でない(数値、文字定数など)→ データ
        out.append(".byte " + conv_data(s, ctx))
        return
    word, rest = m.group(1), m.group(2)
    up = word.upper()

    # DCI"..." / DT"..." (引用符が語に連続する形も含む)
    m2 = re.match(r'^(DCI|DT)\s*(\(?)\s*("[^"]*")\s*\)?\s*$', s, re.I)
    if m2:
        kind, arg = m2.group(1).upper(), m2.group(3)
        if kind == "DCI":
            out.append("Q .set Q+1")
            ctx.consts.add("Q")
            out.append(conv_string_bytes(arg))
        else:
            out.append('.byte "%s"' % arg[1:-1])
        return

    if up in ("TITLE", "SEARCH", "PAGE", "SUBTTL", "PURGE", "PRINTX", "END", "SALL", "XLIST", "LIST", ".XCREF", ".CREF", "HRRZ", "HRLI", "JRST"):
        return
    if up == "RADIX":
        ctx.radix = int(rest.strip())
        return
    if up == "ORG":
        v = squeezed[3:]
        if v in ("0",):
            return
        if v == "255":
            out.append(".res 255-(*-zp_base)")
            return
        if v == "ROMLOC":
            out.append('.segment "CODE"')
            out.append(".org $C000")
            out.append("    jmp INIT   ; 本ボード用: ROM 先頭からの冷開始エントリ")
            return
        if v == "80":  # Apple 構成専用(本構成では無効なブロック内)
            out.append("; (ORG 80 は Apple 構成専用のため省略)")
            return
        out.append("; !! 未変換: ORG " + v)
        ctx.unconverted += 1
        return
    if up == "BLOCK":
        out.append(".res " + conv_expr(rest, ctx))
        return
    if up == "EXP":
        out.append(".byte " + conv_data(rest, ctx))
        return
    if up == "ADR":
        m3 = re.match(r"^\((.*)\)$", rest.strip())
        if m3:
            out.append(".word " + conv_expr(m3.group(1), ctx))
            return
    if up == "XWD":
        parts = [p.strip() for p in rest.split(",")]
        if len(parts) == 2:
            out.append(".byte " + conv_expr(parts[1], ctx))
            return
    if up == "ROR" and not re.match(r"^A\b", rest.strip(), re.I):
        out.append("ror_m " + conv_operand(rest, ctx))
        return
    if up in MNEMONICS:
        op = conv_operand(rest, ctx)
        if op.startswith("("):  # 間接指定と誤解されないよう 0+ を前置する
            op = "0+" + op
        op = re.sub(r"^A$", "a", op, flags=re.I)
        out.append(("    %s %s" % (up.lower(), op)).rstrip())
        return
    if up == "DC":
        arg = rest.strip()
        if arg.startswith("(") and arg.endswith(")"):
            arg = arg[1:-1]
        out.append("    DC " + arg)
        return
    if up in LIBRARY_MACROS or up in ctx.macros:
        out.append(("    %s %s" % (word, conv_operand(rest, ctx))).rstrip())
        return
    if up in ("SKIP1", "SKIP2", "ACRLF"):
        out.append("    " + word)
        return
    # それ以外は、先頭の語を含む式のデータとみなす
    out.append(".byte " + conv_data(s, ctx))


def conv_data(s, ctx):
    parts = [conv_expr(p, ctx) for p in s.split(",") if p.strip()]
    return ", ".join(parts)


def conv_nodes(nodes, ctx, out):
    for node in nodes:
        if ctx.stop:
            return
        if node[0] == "stmt":
            try:
                conv_stmt(node[1], ctx, out)
            except Exception as ex:  # 変換不能は印を残して続行
                out.append("; !! 未変換: %s  (%s)" % (node[1], ex))
                ctx.unconverted += 1
            continue
        _, header, body = node
        m = re.match(r"^(\w+)\s*(.*?),$", header, re.S)
        kind = m.group(1).upper()
        arg = m.group(2).strip()
        if kind in ("IF1", "IF2", "IRPC"):
            continue
        if kind in ("IFE", "IFN"):
            op = "=" if kind == "IFE" else "<>"
            out.append(".if (%s) %s 0" % (conv_expr(arg, ctx), op))
            conv_nodes(body, ctx, out)
            out.append(".endif")
        elif kind == "IFDEF":
            out.append(".ifdef %s" % arg)
            conv_nodes(body, ctx, out)
            out.append(".endif")
        elif kind == "IFNDEF":
            out.append(".ifndef %s" % arg)
            conv_nodes(body, ctx, out)
            out.append(".endif")
        elif kind == "REPEAT":
            out.append(".repeat %s" % conv_expr(arg, ctx))
            conv_nodes(body, ctx, out)
            out.append(".endrepeat")
        elif kind == "DEFINE":
            conv_define(arg, body, ctx, out)
        else:
            out.append("; !! 未変換ブロック: " + header)
            ctx.unconverted += 1


def conv_define(arg, body, ctx, out):
    m = re.match(r"^(\w+)\s*(?:\(([^)]*)\))?\s*$", arg)
    name = m.group(1)
    params = (m.group(2) or "").replace(" ", "")
    if name.upper() in ("DT", "DCI", "DC"):
        return  # 文字列マクロは conv_stmt が直接展開する
    ctx.macros.add(name.upper())
    mname = "ror_m" if name.upper() == "ROR" else name
    # レジスタ名と衝突する仮引数(A、X、Y)は別名にする
    plist = [x for x in params.split(",") if x]
    rename = {x: x + "_arg" for x in plist if x.upper() in ("A", "X", "Y")}
    params = ",".join(rename.get(x, x) for x in plist)
    out.append(".macro %s %s" % (mname, params))
    uses_local = any("%Q" in n[1] for n in body if n[0] == "stmt")
    if uses_local:
        out.append(".local Q__local")
    ctx.in_define = True
    start = len(out)
    conv_nodes(body, ctx, out)
    ctx.in_define = False
    for k in range(start, len(out)):
        for old_name, new_name in rename.items():
            out[k] = re.sub(r"(?<![A-Za-z0-9_$.%])" + old_name + r"(?![A-Za-z0-9_$%])", new_name, out[k])
    out.append(".endmacro")


def main():
    text = SRC.read_text(encoding="latin-1")
    text = strip_comment_blocks(text)
    text = strip_line_comments(text)
    nodes, _ = parse(text, 0, False)
    ctx = Ctx()
    out = [
        "; ca65 用に変換した Microsoft BASIC for 6502 v1.1。",
        "; 原典: Microsoft Corporation (MIT License)。ROM/basic/upstream/LICENSE を参照。",
        "; このファイルは Tools/convert_m6502.py が生成する。直接編集しない。",
        '.include "prelude.inc"',
        '.segment "ZEROPAGE"',
        ".org $0000",
        "zp_base:",
    ]
    conv_nodes(nodes, ctx, out)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    body = "\n".join(out) + "\n"
    for old, new in POST_PATCHES.items():
        if body.count(old) != 1:
            raise SystemExit("追加の差し替え先が見つからない: %r" % old)
        body = body.replace(old, new)
    OUT.write_text(body, encoding="utf-8")
    print("出力: %s (%d 行、未変換 %d 件)" % (OUT, len(out), ctx.unconverted))


if __name__ == "__main__":
    sys.exit(main())
