#!/usr/bin/env python3
"""マニュアル第5章(命令リファレンス)の、オペコード表とフラグ表を生成する。

使い方:
    python3 Tools/gen_manual_opcodes.py           # manual/ja/05-*.md のマーカー間を書き換える
    python3 Tools/gen_manual_opcodes.py --check   # 書き換えが不要なら 0、差があれば 1 を返す

元データ: Sources/Core6502/OpcodeTable.swift の `table`(NMOS 6502 の公式 151 命令)。
マーカー:
    <!-- opcodes:LDA --> ... <!-- /opcodes:LDA -->   オペコード表
    <!-- flags:LDA -->   ... <!-- /flags:LDA -->     フラグ表
    <!-- list -->        ... <!-- /list -->          全命令の一覧(05-reference.md)
標準ライブラリのみを使う。
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SWIFT = os.path.join(ROOT, "Sources", "Core6502", "OpcodeTable.swift")
MANUAL = os.path.join(ROOT, "manual", "ja")

# 分類: キー -> (ファイル名, タイトル)
GROUPS = {
    "load-store": ("05-1-load-store.md", "ロードとストア"),
    "transfer": ("05-2-transfer.md", "レジスタ間の転送"),
    "arithmetic": ("05-3-arithmetic.md", "算術演算と比較"),
    "logic-shift": ("05-4-logic-shift.md", "論理演算とシフト"),
    "branch-jump": ("05-5-branch-jump.md", "分岐とジャンプ"),
    "stack-flags": ("05-6-stack-flags.md", "スタックとフラグ操作"),
}

# フラグ表の列。N V D I Z C の順。記号: ○ 結果で変わる / - 変わらない / 0 1 そのまま設定 / M7 M6 メモリのビット / 復元 スタックから戻す
FL = ["N", "V", "D", "I", "Z", "C"]


def fl(spec):
    """'NZ' のような文字列から、フラグ表の行を作る。spec は {フラグ: 記号} または変化するフラグの文字列。"""
    if isinstance(spec, str):
        spec = {c: "○" for c in spec}
    return {f: spec.get(f, "-") for f in FL}


# ニーモニック: (分類, 英語名, 日本語名, 機能の分類(一覧用), フラグ)
INSTR = [
    ("LDA", "load-store", "Load Accumulator", "ロード A", "メモリの値を A に入れる", fl("NZ")),
    ("LDX", "load-store", "Load X Register", "ロード X", "メモリの値を X に入れる", fl("NZ")),
    ("LDY", "load-store", "Load Y Register", "ロード Y", "メモリの値を Y に入れる", fl("NZ")),
    ("STA", "load-store", "Store Accumulator", "ストア A", "A の値をメモリに書く", fl("")),
    ("STX", "load-store", "Store X Register", "ストア X", "X の値をメモリに書く", fl("")),
    ("STY", "load-store", "Store Y Register", "ストア Y", "Y の値をメモリに書く", fl("")),
    ("TAX", "transfer", "Transfer A to X", "A を X へ転送", "A の値を X にコピーする", fl("NZ")),
    ("TAY", "transfer", "Transfer A to Y", "A を Y へ転送", "A の値を Y にコピーする", fl("NZ")),
    ("TXA", "transfer", "Transfer X to A", "X を A へ転送", "X の値を A にコピーする", fl("NZ")),
    ("TYA", "transfer", "Transfer Y to A", "Y を A へ転送", "Y の値を A にコピーする", fl("NZ")),
    ("TSX", "transfer", "Transfer Stack Pointer to X", "SP を X へ転送", "SP の値を X にコピーする", fl("NZ")),
    ("TXS", "transfer", "Transfer X to Stack Pointer", "X を SP へ転送", "X の値を SP にコピーする", fl("")),
    ("ADC", "arithmetic", "Add with Carry", "キャリー付き加算", "A にメモリの値とキャリーを足す", fl("NVZC")),
    ("SBC", "arithmetic", "Subtract with Carry", "キャリー付き減算", "A からメモリの値と借りを引く", fl("NVZC")),
    ("CMP", "arithmetic", "Compare Accumulator", "A の比較", "A とメモリの値を比べる", fl("NZC")),
    ("CPX", "arithmetic", "Compare X Register", "X の比較", "X とメモリの値を比べる", fl("NZC")),
    ("CPY", "arithmetic", "Compare Y Register", "Y の比較", "Y とメモリの値を比べる", fl("NZC")),
    ("INC", "arithmetic", "Increment Memory", "メモリを 1 増やす", "メモリの値に 1 を足す", fl("NZ")),
    ("DEC", "arithmetic", "Decrement Memory", "メモリを 1 減らす", "メモリの値から 1 を引く", fl("NZ")),
    ("INX", "arithmetic", "Increment X Register", "X を 1 増やす", "X に 1 を足す", fl("NZ")),
    ("INY", "arithmetic", "Increment Y Register", "Y を 1 増やす", "Y に 1 を足す", fl("NZ")),
    ("DEX", "arithmetic", "Decrement X Register", "X を 1 減らす", "X から 1 を引く", fl("NZ")),
    ("DEY", "arithmetic", "Decrement Y Register", "Y を 1 減らす", "Y から 1 を引く", fl("NZ")),
    ("AND", "logic-shift", "Logical AND", "論理積", "A とメモリの値のビットごとの AND", fl("NZ")),
    ("ORA", "logic-shift", "Logical OR", "論理和", "A とメモリの値のビットごとの OR", fl("NZ")),
    ("EOR", "logic-shift", "Exclusive OR", "排他的論理和", "A とメモリの値のビットごとの XOR", fl("NZ")),
    ("BIT", "logic-shift", "Bit Test", "ビットテスト", "A とメモリの値を AND して Z を決め、メモリの上位 2 ビットを N と V に写す",
     fl({"N": "M7", "V": "M6", "Z": "○"})),
    ("ASL", "logic-shift", "Arithmetic Shift Left", "算術左シフト", "左に 1 ビットずらし、最上位ビットを C に出す", fl("NZC")),
    ("LSR", "logic-shift", "Logical Shift Right", "論理右シフト", "右に 1 ビットずらし、最下位ビットを C に出す", fl({"N": "0", "Z": "○", "C": "○"})),
    ("ROL", "logic-shift", "Rotate Left", "左ローテート", "C を含めて左に 1 ビット回す", fl("NZC")),
    ("ROR", "logic-shift", "Rotate Right", "右ローテート", "C を含めて右に 1 ビット回す", fl("NZC")),
    ("BCC", "branch-jump", "Branch if Carry Clear", "C が 0 なら分岐", "C が 0 のとき分岐する", fl("")),
    ("BCS", "branch-jump", "Branch if Carry Set", "C が 1 なら分岐", "C が 1 のとき分岐する", fl("")),
    ("BEQ", "branch-jump", "Branch if Equal", "Z が 1 なら分岐", "Z が 1 のとき分岐する", fl("")),
    ("BNE", "branch-jump", "Branch if Not Equal", "Z が 0 なら分岐", "Z が 0 のとき分岐する", fl("")),
    ("BMI", "branch-jump", "Branch if Minus", "N が 1 なら分岐", "N が 1 のとき分岐する", fl("")),
    ("BPL", "branch-jump", "Branch if Plus", "N が 0 なら分岐", "N が 0 のとき分岐する", fl("")),
    ("BVC", "branch-jump", "Branch if Overflow Clear", "V が 0 なら分岐", "V が 0 のとき分岐する", fl("")),
    ("BVS", "branch-jump", "Branch if Overflow Set", "V が 1 なら分岐", "V が 1 のとき分岐する", fl("")),
    ("JMP", "branch-jump", "Jump", "ジャンプ", "指定の番地へ飛ぶ", fl("")),
    ("JSR", "branch-jump", "Jump to Subroutine", "サブルーチン呼び出し", "戻り番地を積んで、指定の番地へ飛ぶ", fl("")),
    ("RTS", "branch-jump", "Return from Subroutine", "サブルーチンから戻る", "戻り番地を取り出して戻る", fl("")),
    ("BRK", "branch-jump", "Break", "ブレーク", "ソフトウェア割り込みを起こす", fl({"I": "1"})),
    ("RTI", "branch-jump", "Return from Interrupt", "割り込みから戻る", "P と戻り番地を取り出して戻る",
     fl({f: "復元" for f in FL})),
    ("PHA", "stack-flags", "Push Accumulator", "A を積む", "A をスタックに積む", fl("")),
    ("PLA", "stack-flags", "Pull Accumulator", "A に取り出す", "スタックから A に取り出す", fl("NZ")),
    ("PHP", "stack-flags", "Push Processor Status", "P を積む", "P をスタックに積む", fl("")),
    ("PLP", "stack-flags", "Pull Processor Status", "P に取り出す", "スタックから P に取り出す",
     fl({f: "復元" for f in FL})),
    ("CLC", "stack-flags", "Clear Carry Flag", "C を 0 にする", "C を 0 にする", fl({"C": "0"})),
    ("SEC", "stack-flags", "Set Carry Flag", "C を 1 にする", "C を 1 にする", fl({"C": "1"})),
    ("CLI", "stack-flags", "Clear Interrupt Disable", "I を 0 にする", "割り込みを許可する", fl({"I": "0"})),
    ("SEI", "stack-flags", "Set Interrupt Disable", "I を 1 にする", "割り込みを禁止する", fl({"I": "1"})),
    ("CLD", "stack-flags", "Clear Decimal Mode", "D を 0 にする", "10進モードを解除する", fl({"D": "0"})),
    ("SED", "stack-flags", "Set Decimal Mode", "D を 1 にする", "10進モードにする", fl({"D": "1"})),
    ("CLV", "stack-flags", "Clear Overflow Flag", "V を 0 にする", "V を 0 にする", fl({"V": "0"})),
    ("NOP", "stack-flags", "No Operation", "何もしない", "何もしない", fl("")),
]

MODE_ORDER = ["implied", "accumulator", "immediate", "zeroPage", "zeroPageX", "zeroPageY", "absolute",
              "absoluteX", "absoluteY", "indirect", "indexedIndirect", "indirectIndexed", "relative"]
MODE_NAME = {
    "implied": "インプライド", "accumulator": "アキュムレータ", "immediate": "イミディエイト",
    "zeroPage": "ゼロページ", "zeroPageX": "ゼロページ X", "zeroPageY": "ゼロページ Y",
    "absolute": "アブソリュート", "absoluteX": "アブソリュート X", "absoluteY": "アブソリュート Y",
    "indirect": "インダイレクト", "indexedIndirect": "インデックスト・インダイレクト",
    "indirectIndexed": "インダイレクト・インデックスト", "relative": "リラティブ",
}
MODE_SYNTAX = {
    "implied": "{m}", "accumulator": "{m} A", "immediate": "{m} #$nn", "zeroPage": "{m} $nn",
    "zeroPageX": "{m} $nn,X", "zeroPageY": "{m} $nn,Y", "absolute": "{m} $nnnn", "absoluteX": "{m} $nnnn,X",
    "absoluteY": "{m} $nnnn,Y", "indirect": "{m} ($nnnn)", "indexedIndirect": "{m} ($nn,X)",
    "indirectIndexed": "{m} ($nn),Y", "relative": "{m} label",
}
MODE_BYTES = {"implied": 1, "accumulator": 1, "immediate": 2, "zeroPage": 2, "zeroPageX": 2, "zeroPageY": 2,
              "relative": 2, "indexedIndirect": 2, "indirectIndexed": 2, "absolute": 3, "absoluteX": 3,
              "absoluteY": 3, "indirect": 3}
# Operation.addsCycleOnPageCross に対応
PAGE_CROSS_OPS = {"adc", "and", "bit", "cmp", "eor", "lda", "ldx", "ldy", "ora", "sbc"}
PAGE_CROSS_MODES = {"absoluteX", "absoluteY", "indirectIndexed"}


def load_table():
    """OpcodeTable.swift の `table`(NMOS 6502)から {ニーモニック: [(オペコード, モード, サイクル)]} を作る。"""
    src = open(SWIFT, encoding="utf-8").read()
    start = src.index("static let table:")
    end = src.index("static let table65C02")
    body = src[start:end]
    result = {}
    for m in re.finditer(r"t\[0x([0-9A-F]{2})\] = Instruction\(op: \.(\w+), mode: \.(\w+), cycles: (\d+)\)", body):
        code, op, mode, cyc = int(m.group(1), 16), m.group(2), m.group(3), int(m.group(4))
        result.setdefault(op.upper(), []).append((code, mode, cyc))
    return result


def cycles_text(op, mode, cyc):
    if mode == "relative":
        return f"{cyc} (+1,+2)"
    if op.lower() in PAGE_CROSS_OPS and mode in PAGE_CROSS_MODES:
        return f"{cyc}+"
    return str(cyc)


def opcode_table(mn, table):
    rows = sorted(table[mn], key=lambda r: (MODE_ORDER.index(r[1]), r[0]))
    out = ["| アドレッシングモード | 書き方 | オペコード | バイト数 | サイクル数 |", "|---|---|---|---|---|"]
    for code, mode, cyc in rows:
        syn = MODE_SYNTAX[mode].format(m=mn)
        out.append(f"| {MODE_NAME[mode]} | `{syn}` | `${code:02X}` | {MODE_BYTES[mode]} | {cycles_text(mn, mode, cyc)} |")
    return "\n".join(out)


def flag_table(flags):
    head = "| " + " | ".join(FL) + " |"
    sep = "|" + "---|" * len(FL)
    row = "| " + " | ".join(flags[f] for f in FL) + " |"
    return "\n".join([head, sep, row])


def flag_summary(flags):
    ch = [f for f in FL if flags[f] != "-"]
    return " ".join(ch) if ch else "なし"


def list_table():
    out = ["| ニーモニック | 名前 | 機能 | 影響するフラグ |", "|---|---|---|---|"]
    for mn, group, eng, jp, func, flags in INSTR:
        fname = GROUPS[group][0]
        out.append(f"| [{mn}]({fname}#{mn.lower()}) | {eng}({jp}) | {func} | {flag_summary(flags)} |")
    return "\n".join(out)


def replace_block(text, tag, content):
    """<!-- tag --> と <!-- /tag --> の間を content に置き換える。マーカーがなければ None。"""
    pat = re.compile(r"(<!-- " + re.escape(tag) + r" -->)\n(?:.*?\n)?(<!-- /" + re.escape(tag) + r" -->)", re.S)
    if not pat.search(text):
        return None
    return pat.sub(lambda m: m.group(1) + "\n" + content + "\n" + m.group(2), text, count=1)


def main():
    check = "--check" in sys.argv
    table = load_table()
    assert sum(len(v) for v in table.values()) == 151, "公式命令は 151 個のはず"
    assert {i[0] for i in INSTR} == set(table), "ニーモニックの集合が表と一致しない"
    problems = []
    files = {}

    def get(fname):
        if fname not in files:
            path = os.path.join(MANUAL, fname)
            files[fname] = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        return files[fname]

    def apply(fname, tag, content):
        text = get(fname)
        if text is None:
            problems.append(f"{fname}: ファイルがない")
            return
        new = replace_block(text, tag, content)
        if new is None:
            problems.append(f"{fname}: マーカー <!-- {tag} --> がない")
            return
        if new != text:
            problems.append(f"{fname}: <!-- {tag} --> の内容が表と違う")
            files[fname] = new

    for mn, group, eng, jp, func, flags in INSTR:
        fname = GROUPS[group][0]
        apply(fname, f"opcodes:{mn}", opcode_table(mn, table))
        apply(fname, f"flags:{mn}", flag_table(flags))
    apply("05-reference.md", "list", list_table())

    if check:
        for p in problems:
            print(p)
        return 1 if problems else 0
    for fname, text in files.items():
        if text is not None:
            with open(os.path.join(MANUAL, fname), "w", encoding="utf-8") as f:
                f.write(text)
    hard = [p for p in problems if "がない" in p]
    for p in hard:
        print(p)
    print(f"{len([p for p in problems if '内容が表と違う' in p])} 個のブロックを更新した")
    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main())
