#!/usr/bin/env python3
"""Sources/Core6502/OpcodeTable.swift から、モニタの逆アセンブラ用の表を生成する。

出力: ROM/disasm_tables.inc(ca65)
- MNEM:     ニーモニック(3 文字 × 70 個)。添字は Operation の宣言順(adc, and, asl, ...)。
- BITOP_FIRST: 数字付きで表示するニーモニック(rmb、smb、bbr、bbs)の最初の添字。数字はオペコードの bit4-6。
- OPMN:     NMOS 6502 のオペコード(0-255)→ ニーモニックの添字。未定義は $FF。
- OPMODE:   オペコード → アドレッシングモード番号(AddressingMode の宣言順)。
- OPMN65:   65C02 の OPMN(256 命令すべてが定義済み)。
- OPMODE65: 65C02 の OPMODE。

CPU コアの表が唯一の元データなので、手で写して誤る心配がない。
65C02 の表は、OpcodeTable.swift の `table65C02`(NMOS の表を複製して差し替える)と同じ手順で作る。
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
src = (root / "Sources/Core6502/OpcodeTable.swift").read_text()

ops_block = re.search(r"enum Operation: UInt8 \{\n(.*?)\n\s+case illegal", src, re.S).group(1)
ops = [o.strip() for line in ops_block.splitlines()
       if re.match(r"\s+case ", line)
       for o in re.sub(r"\s*//.*$", "", re.sub(r"^\s*case ", "", line)).split(",")]
mode_block = re.search(r"enum AddressingMode: UInt8 \{\n(.*?)\n\}", src, re.S).group(1)
modes = [m.strip() for line in mode_block.splitlines()
         if re.match(r"\s+case ", line)
         for m in re.sub(r"\s*//.*$", "", re.sub(r"^\s*case ", "", line)).split(",")]
assert len(ops) == 70 and len(modes) == 16, (len(ops), len(modes))
assert ops[-4:] == ["rmb", "smb", "bbr", "bbs"], ops[-4:]

split = src.index("static let table65C02")
nmos_src, cmos_src = src[:split], src[split:]
entry = re.compile(r"t\[0x([0-9A-F]{2})\] = Instruction\(op: \.(\w+), mode: \.(\w+),")

opmn = [0xFF] * 256
opmode = [0] * 256
for m in entry.finditer(nmos_src):
    code = int(m.group(1), 16)
    opmn[code] = ops.index(m.group(2))
    opmode[code] = modes.index(m.group(3))
assert sum(1 for x in opmn if x != 0xFF) == 151

# 65C02: NMOS の表を複製し、table65C02 の記述で追加・差し替える
opmn65 = list(opmn)
opmode65 = list(opmode)
for m in entry.finditer(cmos_src):
    code = int(m.group(1), 16)
    opmn65[code] = ops.index(m.group(2))
    opmode65[code] = modes.index(m.group(3))
assert all(x != 0xFF for x in opmn65), "65C02 の表に未定義のオペコードが残っている"

def rows(values, per=16):
    return "\n".join("        .byte " + ", ".join("$%02X" % v for v in values[i:i + per])
                     for i in range(0, len(values), per))

out = [
    "; Tools/gen_disasm_tables.py が生成する。直接編集しない。",
    "; 元データ: Sources/Core6502/OpcodeTable.swift(NMOS 6502 の公式 151 命令と、65C02 の 256 命令)",
    "",
    "; アドレッシングモード番号: " + ", ".join("%d=%s" % (i, m) for i, m in enumerate(modes)),
    "MNEM:",
    "\n".join('        .byte "%s"' % o.upper() for o in ops),
    "",
    "; この番号以上のニーモニック(RMB、SMB、BBR、BBS)は、3 文字のあとにオペコードの bit4-6 を数字で付ける",
    "BITOP_FIRST = %d" % ops.index("rmb"),
    "",
    "OPMN:",
    rows(opmn),
    "",
    "OPMODE:",
    rows(opmode),
    "",
    "OPMN65:",
    rows(opmn65),
    "",
    "OPMODE65:",
    rows(opmode65),
    "",
]
(root / "ROM/disasm_tables.inc").write_text("\n".join(out))
print("ROM/disasm_tables.inc: %d ニーモニック、NMOS %d 命令、65C02 %d 命令、%d モード" % (len(ops), 151, 256, len(modes)))
