#!/usr/bin/env python3
"""マニュアル第5章(命令リファレンス)の、オペコード表とフラグ表を生成する。

使い方:
    python3 Tools/gen_manual_opcodes.py           # manual/ja/05-*.md と manual/en/05-*.md のマーカー間を書き換える
    python3 Tools/gen_manual_opcodes.py --check   # 書き換えが不要なら 0、差があれば 1 を返す
    --lang ja|en|all                              # 対象の言語(省略時は all)

元データ: Sources/Core6502/OpcodeTable.swift の `table`(NMOS 6502 の公式 151 命令)と、
`table65C02`(65C02。05-7-65c02.md の表に使う。NMOS から増えた、または変わったオペコードだけを載せる)。
マーカー:
    <!-- opcodes:LDA --> ... <!-- /opcodes:LDA -->   オペコード表
    <!-- flags:LDA -->   ... <!-- /flags:LDA -->     フラグ表
    <!-- list -->        ... <!-- /list -->          全命令の一覧(05-reference.md)
    <!-- list65 -->      ... <!-- /list65 -->        65C02 で加わる命令の一覧(05-7-65c02.md)
    05-7-65c02.md では、opcodes:BRA のように、命令ごとのオペコード表(65C02 の新規・変更分)を使う。
標準ライブラリのみを使う。
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SWIFT = os.path.join(ROOT, "Sources", "Core6502", "OpcodeTable.swift")
MANUAL_DIR = {"ja": os.path.join(ROOT, "manual", "ja"), "en": os.path.join(ROOT, "manual", "en")}

# 分類: キー -> (ファイル名, タイトル)
GROUPS = {
    "load-store": ("05-1-load-store.md", "ロードとストア"),
    "transfer": ("05-2-transfer.md", "レジスタ間の転送"),
    "arithmetic": ("05-3-arithmetic.md", "算術演算と比較"),
    "logic-shift": ("05-4-logic-shift.md", "論理演算とシフト"),
    "branch-jump": ("05-5-branch-jump.md", "分岐とジャンプ"),
    "stack-flags": ("05-6-stack-flags.md", "スタックとフラグ操作"),
}
FILE_65C02 = "05-7-65c02.md"

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
              "absoluteX", "absoluteY", "indirect", "indexedIndirect", "indirectIndexed", "relative",
              "zeroPageIndirect", "absoluteIndexedIndirect", "zeroPageRelative"]
MODE_NAME = {
    "implied": "インプライド", "accumulator": "アキュムレータ", "immediate": "イミディエイト",
    "zeroPage": "ゼロページ", "zeroPageX": "ゼロページ X", "zeroPageY": "ゼロページ Y",
    "absolute": "アブソリュート", "absoluteX": "アブソリュート X", "absoluteY": "アブソリュート Y",
    "indirect": "インダイレクト", "indexedIndirect": "インデックスト・インダイレクト",
    "indirectIndexed": "インダイレクト・インデックスト", "relative": "リラティブ",
    "zeroPageIndirect": "ゼロページ・インダイレクト", "absoluteIndexedIndirect": "アブソリュート X・インダイレクト",
    "zeroPageRelative": "ゼロページ・リラティブ",
}
MODE_SYNTAX = {
    "implied": "{m}", "accumulator": "{m} A", "immediate": "{m} #$nn", "zeroPage": "{m} $nn",
    "zeroPageX": "{m} $nn,X", "zeroPageY": "{m} $nn,Y", "absolute": "{m} $nnnn", "absoluteX": "{m} $nnnn,X",
    "absoluteY": "{m} $nnnn,Y", "indirect": "{m} ($nnnn)", "indexedIndirect": "{m} ($nn,X)",
    "indirectIndexed": "{m} ($nn),Y", "relative": "{m} label",
    "zeroPageIndirect": "{m} ($nn)", "absoluteIndexedIndirect": "{m} ($nnnn,X)", "zeroPageRelative": "{m} $nn,label",
}
MODE_BYTES = {"implied": 1, "accumulator": 1, "immediate": 2, "zeroPage": 2, "zeroPageX": 2, "zeroPageY": 2,
              "relative": 2, "indexedIndirect": 2, "indirectIndexed": 2, "absolute": 3, "absoluteX": 3,
              "absoluteY": 3, "indirect": 3, "zeroPageIndirect": 2, "absoluteIndexedIndirect": 3,
              "zeroPageRelative": 3}
# Operation.addsCycleOnPageCross に対応
PAGE_CROSS_OPS = {"adc", "and", "bit", "cmp", "eor", "lda", "ldx", "ldy", "ora", "sbc"}
PAGE_CROSS_MODES = {"absoluteX", "absoluteY", "indirectIndexed"}
SHIFT_OPS = {"asl", "lsr", "rol", "ror"}  # 65C02 では abs,X もページ跨ぎで 1 サイクル増える
BRANCH_MODES = {"relative", "zeroPageRelative"}

# 言語別の設定。ja の出力は従来と同じでなければならない。
LANG = {
    "ja": {
        "group_title": {k: v[1] for k, v in GROUPS.items()},
        "mode_name": MODE_NAME,
        "opcode_head": ["アドレッシングモード", "書き方", "オペコード", "バイト数", "サイクル数"],
        "list_head": ["ニーモニック", "名前", "機能", "影響するフラグ"],
        "none": "なし",
        "restored": "復元",
        "page_cross": "{c}+",
        "branch": "{c} (+1,+2)",
        "branch_always": "{c} (+1)",
        "nop_head": ["バイト数", "サイクル数", "オペコード"],
    },
    "en": {
        "mode_name": {
            "implied": "Implied", "accumulator": "Accumulator", "immediate": "Immediate",
            "zeroPage": "Zero page", "zeroPageX": "Zero page,X", "zeroPageY": "Zero page,Y",
            "absolute": "Absolute", "absoluteX": "Absolute,X", "absoluteY": "Absolute,Y",
            "indirect": "Indirect", "indexedIndirect": "Indexed indirect `(zp,X)`",
            "indirectIndexed": "Indirect indexed `(zp),Y`", "relative": "Relative",
            "zeroPageIndirect": "Zero page indirect `(zp)`", "absoluteIndexedIndirect": "Absolute,X indirect `(abs,X)`",
            "zeroPageRelative": "Zero page relative",
        },
        "opcode_head": ["Addressing mode", "Syntax", "Opcode", "Bytes", "Cycles"],
        "list_head": ["Mnemonic", "Name", "Function", "Flags affected"],
        "none": "None",
        "restored": "Restored",
        "page_cross": "{c}+",
        "branch": "{c} (+1, +2)",
        "branch_always": "{c} (+1)",
        "nop_head": ["Bytes", "Cycles", "Opcodes"],
    },
}

# 英語版の一覧用の機能説明(INSTR の日本語の説明に対応する)
FUNC_EN = {
    "LDA": "Loads a value from memory into A", "LDX": "Loads a value from memory into X",
    "LDY": "Loads a value from memory into Y", "STA": "Writes the value of A to memory",
    "STX": "Writes the value of X to memory", "STY": "Writes the value of Y to memory",
    "TAX": "Copies the value of A to X", "TAY": "Copies the value of A to Y",
    "TXA": "Copies the value of X to A", "TYA": "Copies the value of Y to A",
    "TSX": "Copies the value of SP to X", "TXS": "Copies the value of X to SP",
    "ADC": "Adds the memory value and the carry to A", "SBC": "Subtracts the memory value and the borrow from A",
    "CMP": "Compares A with a memory value", "CPX": "Compares X with a memory value",
    "CPY": "Compares Y with a memory value", "INC": "Adds 1 to a memory value",
    "DEC": "Subtracts 1 from a memory value", "INX": "Adds 1 to X", "INY": "Adds 1 to Y",
    "DEX": "Subtracts 1 from X", "DEY": "Subtracts 1 from Y",
    "AND": "Bitwise AND of A and a memory value", "ORA": "Bitwise OR of A and a memory value",
    "EOR": "Bitwise XOR of A and a memory value",
    "BIT": "ANDs A with a memory value to set Z, and copies the top 2 bits of the memory value to N and V",
    "ASL": "Shifts left by 1 bit; the most significant bit goes out to C",
    "LSR": "Shifts right by 1 bit; the least significant bit goes out to C",
    "ROL": "Rotates left by 1 bit through C", "ROR": "Rotates right by 1 bit through C",
    "BCC": "Branches if C is 0", "BCS": "Branches if C is 1", "BEQ": "Branches if Z is 1",
    "BNE": "Branches if Z is 0", "BMI": "Branches if N is 1", "BPL": "Branches if N is 0",
    "BVC": "Branches if V is 0", "BVS": "Branches if V is 1", "JMP": "Jumps to the given address",
    "JSR": "Pushes the return address and jumps to the given address",
    "RTS": "Pulls the return address and returns", "BRK": "Causes a software interrupt",
    "RTI": "Pulls P and the return address and returns",
    "PHA": "Pushes A onto the stack", "PLA": "Pulls A from the stack", "PHP": "Pushes P onto the stack",
    "PLP": "Pulls P from the stack", "CLC": "Sets C to 0", "SEC": "Sets C to 1",
    "CLI": "Enables interrupts", "SEI": "Disables interrupts", "CLD": "Leaves decimal mode",
    "SED": "Enters decimal mode", "CLV": "Sets V to 0", "NOP": "Does nothing",
}


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


def cycles_text(op, mode, cyc, lang="ja", cmos=False):
    c = LANG[lang]
    if cmos and op.lower() == "bra":
        return c["branch_always"].format(c=cyc + 1)  # いつも分岐するので 3 サイクル。別ページなら +1
    if mode in BRANCH_MODES:
        return c["branch"].format(c=cyc)
    if op.lower() in PAGE_CROSS_OPS and mode in PAGE_CROSS_MODES:
        return c["page_cross"].format(c=cyc)
    if cmos and op.lower() in SHIFT_OPS and mode == "absoluteX":
        return c["page_cross"].format(c=cyc)
    return str(cyc)


def opcode_table(mn, table, lang="ja"):
    c = LANG[lang]
    rows = sorted(table[mn], key=lambda r: (MODE_ORDER.index(r[1]), r[0]))
    out = ["| " + " | ".join(c["opcode_head"]) + " |", "|---|---|---|---|---|"]
    for code, mode, cyc in rows:
        syn = MODE_SYNTAX[mode].format(m=mn)
        out.append(f"| {c['mode_name'][mode]} | `{syn}` | `${code:02X}` | {MODE_BYTES[mode]} | {cycles_text(mn, mode, cyc, lang)} |")
    return "\n".join(out)


def flag_table(flags, lang="ja"):
    head = "| " + " | ".join(FL) + " |"
    sep = "|" + "---|" * len(FL)
    row = "| " + " | ".join(flags[f].replace("復元", LANG[lang]["restored"]) for f in FL) + " |"
    return "\n".join([head, sep, row])


def flag_summary(flags, lang="ja"):
    ch = [f for f in FL if flags[f] != "-"]
    return " ".join(ch) if ch else LANG[lang]["none"]


def list_table(lang="ja"):
    c = LANG[lang]
    out = ["| " + " | ".join(c["list_head"]) + " |", "|---|---|---|---|"]
    for mn, group, eng, jp, func, flags in INSTR:
        fname = GROUPS[group][0]
        if lang == "ja":
            out.append(f"| [{mn}]({fname}#{mn.lower()}) | {eng}({jp}) | {func} | {flag_summary(flags)} |")
        else:
            slug = f"{mn.lower()}-{eng.lower().replace(' ', '-')}"
            out.append(f"| [{mn}]({fname}#{slug}) | {eng} | {FUNC_EN[mn]} | {flag_summary(flags, lang)} |")
    return "\n".join(out)


# ---- 65C02(05-7-65c02.md)----

ASSIGN_RE = re.compile(r"t\[0x([0-9A-F]{2})\] = Instruction\(op: \.(\w+), mode: \.(\w+), cycles: (\d+)\)")


def load_65c02():
    """NMOS の表と 65C02 の表から、NMOS と違うオペコードだけを [(コード, op, モード, サイクル)] で返す。"""
    src = open(SWIFT, encoding="utf-8").read()
    i1, i2 = src.index("static let table:"), src.index("static let table65C02")
    nmos = {int(m[0], 16): (m[1], m[2], int(m[3])) for m in ASSIGN_RE.findall(src[i1:i2])}
    c02 = dict(nmos)
    for m in ASSIGN_RE.findall(src[i2:]):
        c02[int(m[0], 16)] = (m[1], m[2], int(m[3]))
    assert len(c02) == 256, "65C02 は 256 オペコードすべてを定義するはず"
    assert all(v[0] != "illegal" for v in c02.values()), "65C02 に未定義が残っている"
    return [(code, *c02[code]) for code in range(256) if nmos.get(code) != c02[code]]


def mnemonic65(code, op):
    """RMB/SMB/BBR/BBS は、オペコードの bit4-6 を番号にして RMB0 のように書く。"""
    if op in ("rmb", "smb", "bbr", "bbs"):
        return f"{op.upper()}{(code >> 4) & 7}"
    return op.upper()


NEW_MNEMONICS = ["BRA", "PHX", "PHY", "PLX", "PLY", "STZ", "TRB", "TSB", "WAI", "STP", "BBR", "BBS", "RMB", "SMB"]
ZPIND_ORDER = ["ORA", "AND", "EOR", "ADC", "STA", "LDA", "CMP", "SBC"]
SORT_ORDER = ZPIND_ORDER + ["ASL", "LSR", "ROL", "ROR"]


def blocks65(delta):
    """差分のオペコードを、05-7-65c02.md の表(マーカー名)に振り分ける。漏れと重複は許さない。"""
    blocks = {mn: [r for r in delta if r[1] == mn.lower()] for mn in NEW_MNEMONICS}
    blocks["INC"] = [r for r in delta if r[1] == "inc"]
    blocks["DEC"] = [r for r in delta if r[1] == "dec"]
    blocks["ZPIND"] = [r for r in delta if r[2] == "zeroPageIndirect"]
    blocks["BIT"] = [r for r in delta if r[1] == "bit"]
    blocks["JMP"] = [r for r in delta if r[1] == "jmp"]
    blocks["SHIFT"] = [r for r in delta if r[1] in SHIFT_OPS]
    blocks["NOP"] = [r for r in delta if r[1] == "nop"]
    used = [r[0] for rows in blocks.values() for r in rows]
    assert len(used) == len(set(used)), "同じオペコードが 2 つの表に入っている"
    assert set(used) == {r[0] for r in delta}, "表に入っていない差分オペコードがある"
    return blocks


def row_key(r):
    code, op, mode, cyc = r
    mn = mnemonic65(code, op)
    return (MODE_ORDER.index(mode), SORT_ORDER.index(mn) if mn in SORT_ORDER else 0, code)


def opcode_table65(rows, lang="ja"):
    c = LANG[lang]
    out = ["| " + " | ".join(c["opcode_head"]) + " |", "|---|---|---|---|---|"]
    for code, op, mode, cyc in sorted(rows, key=row_key):
        syn = MODE_SYNTAX[mode].format(m=mnemonic65(code, op))
        out.append(f"| {c['mode_name'][mode]} | `{syn}` | `${code:02X}` | {MODE_BYTES[mode]} | "
                   f"{cycles_text(op, mode, cyc, lang, cmos=True)} |")
    return "\n".join(out)


def nop_table65(rows, lang="ja"):
    """未定義だったオペコードが NOP になったもの。バイト数とサイクル数が同じものをまとめる。"""
    c = LANG[lang]
    groups = {}
    for code, op, mode, cyc in rows:
        groups.setdefault((MODE_BYTES[mode], cyc), []).append(code)
    out = ["| " + " | ".join(c["nop_head"]) + " |", "|---|---|---|"]
    for (nbytes, cyc), codes in sorted(groups.items()):
        out.append(f"| {nbytes} | {cyc} | " + ", ".join(f"`${x:02X}`" for x in sorted(codes)) + " |")
    return "\n".join(out)


# 65C02 で加わる命令: (ニーモニック, 英語名, 日本語名, 機能(日本語), 機能(英語), フラグ)
INSTR65 = [
    ("BRA", "Branch Always", "いつも分岐", "いつも分岐する", "Always branches", fl("")),
    ("PHX", "Push X Register", "X を積む", "X をスタックに積む", "Pushes X onto the stack", fl("")),
    ("PHY", "Push Y Register", "Y を積む", "Y をスタックに積む", "Pushes Y onto the stack", fl("")),
    ("PLX", "Pull X Register", "X に取り出す", "スタックから X に取り出す", "Pulls X from the stack", fl("NZ")),
    ("PLY", "Pull Y Register", "Y に取り出す", "スタックから Y に取り出す", "Pulls Y from the stack", fl("NZ")),
    ("STZ", "Store Zero", "0 を書く", "メモリに 0 を書く", "Writes 0 to memory", fl("")),
    ("TRB", "Test and Reset Bits", "ビットを調べて 0 にする",
     "A とメモリを AND して Z を決め、A の 1 のビットをメモリで 0 にする",
     "ANDs A with memory to set Z, then clears in memory the bits that are 1 in A", fl("Z")),
    ("TSB", "Test and Set Bits", "ビットを調べて 1 にする",
     "A とメモリを AND して Z を決め、A の 1 のビットをメモリで 1 にする",
     "ANDs A with memory to set Z, then sets in memory the bits that are 1 in A", fl("Z")),
    ("WAI", "Wait for Interrupt", "割り込みを待つ", "割り込みが来るまで止まる", "Waits until an interrupt arrives", fl("")),
    ("STP", "Stop the Clock", "停止", "RESET まで止まる", "Stops until RESET", fl("")),
    ("BBR", "Branch on Bit Reset", "ビットが 0 なら分岐", "ゼロページの値のビット n が 0 のとき分岐する",
     "Branches if bit n of a zero page value is 0", fl("")),
    ("BBS", "Branch on Bit Set", "ビットが 1 なら分岐", "ゼロページの値のビット n が 1 のとき分岐する",
     "Branches if bit n of a zero page value is 1", fl("")),
    ("RMB", "Reset Memory Bit", "メモリのビットを 0 にする", "ゼロページの値のビット n を 0 にする",
     "Clears bit n of a zero page value", fl("")),
    ("SMB", "Set Memory Bit", "メモリのビットを 1 にする", "ゼロページの値のビット n を 1 にする",
     "Sets bit n of a zero page value", fl("")),
]
# フラグ表のマーカー名 -> フラグ。INSTR65 のほか、INC A、DEC A、BIT の新モードの分
FLAGS65 = {mn: fl_ for mn, _, _, _, _, fl_ in INSTR65}
FLAGS65["INC"] = fl("NZ")
FLAGS65["DEC"] = fl("NZ")
FLAGS65["BIT"] = fl({"N": "M7", "V": "M6", "Z": "○"})
FLAGS65["BIT-IMM"] = fl("Z")


def list_table65(lang="ja"):
    c = LANG[lang]
    out = ["| " + " | ".join(c["list_head"]) + " |", "|---|---|---|---|"]
    for mn, eng, jp, func_ja, func_en, flags in INSTR65:
        if lang == "ja":
            out.append(f"| [{mn}](#{mn.lower()}) | {eng}({jp}) | {func_ja} | {flag_summary(flags)} |")
        else:
            slug = f"{mn.lower()}-{eng.lower().replace(' ', '-')}"
            out.append(f"| [{mn}](#{slug}) | {eng} | {func_en} | {flag_summary(flags, lang)} |")
    return "\n".join(out)


def replace_block(text, tag, content):
    """<!-- tag --> と <!-- /tag --> の間を content に置き換える。マーカーがなければ None。"""
    pat = re.compile(r"(<!-- " + re.escape(tag) + r" -->)\n(?:.*?\n)?(<!-- /" + re.escape(tag) + r" -->)", re.S)
    if not pat.search(text):
        return None
    return pat.sub(lambda m: m.group(1) + "\n" + content + "\n" + m.group(2), text, count=1)


def process(lang, check, table, delta):
    manual = MANUAL_DIR[lang]
    ja = lang == "ja"
    problems = []
    files = {}
    originals = {}

    def get(fname):
        if fname not in files:
            path = os.path.join(manual, fname)
            files[fname] = open(path, encoding="utf-8").read() if os.path.exists(path) else None
            originals[fname] = files[fname]
        return files[fname]

    def apply(fname, tag, content):
        text = get(fname)
        if text is None:
            problems.append(f"{lang}/{fname}: ファイルがない")
            return
        new = replace_block(text, tag, content)
        if new is None:
            problems.append(f"{lang}/{fname}: マーカー <!-- {tag} --> がない")
            return
        if new != text:
            problems.append(f"{lang}/{fname}: <!-- {tag} --> の内容が表と違う")
            files[fname] = new

    for mn, group, eng, jp, func, flags in INSTR:
        fname = GROUPS[group][0]
        apply(fname, f"opcodes:{mn}", opcode_table(mn, table, lang))
        apply(fname, f"flags:{mn}", flag_table(flags, lang))
    apply("05-reference.md", "list", list_table(lang))

    blocks = blocks65(delta)
    for key, rows in blocks.items():
        content = nop_table65(rows, lang) if key == "NOP" else opcode_table65(rows, lang)
        apply(FILE_65C02, f"opcodes:{key}", content)
    for key, flags in FLAGS65.items():
        apply(FILE_65C02, f"flags:{key}", flag_table(flags, lang))
    apply(FILE_65C02, "list65", list_table65(lang))

    if check:
        for p in problems:
            print(p)
        return 1 if problems else 0
    for fname, text in files.items():
        if text is not None and text != originals[fname]:  # 変わらないファイルは書かない(他の作業と衝突させない)
            with open(os.path.join(manual, fname), "w", encoding="utf-8") as f:
                f.write(text)
    hard = [p for p in problems if "がない" in p]
    for p in hard:
        print(p)
    print(f"{lang}: {len([p for p in problems if '内容が表と違う' in p])} 個のブロックを更新した")
    return 1 if hard else 0


def main():
    check = "--check" in sys.argv
    lang = "all"
    if "--lang" in sys.argv:
        lang = sys.argv[sys.argv.index("--lang") + 1]
    if lang not in ("ja", "en", "all"):
        print("--lang は ja、en、all のどれか")
        return 2
    table = load_table()
    assert sum(len(v) for v in table.values()) == 151, "公式命令は 151 個のはず"
    assert {i[0] for i in INSTR} == set(table), "ニーモニックの集合が表と一致しない"
    assert set(FUNC_EN) == set(table), "FUNC_EN が命令と一致しない"
    delta = load_65c02()
    assert {mn for mn, *_ in INSTR65} == set(NEW_MNEMONICS), "INSTR65 と NEW_MNEMONICS が一致しない"
    rc = 0
    for lg in (["ja", "en"] if lang == "all" else [lang]):
        rc |= process(lg, check, table, delta)
    return rc


if __name__ == "__main__":
    sys.exit(main())
