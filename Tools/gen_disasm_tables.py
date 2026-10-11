#!/usr/bin/env python3
"""Sources/Core6502/OpcodeTable.swift から、モニタの逆アセンブラ用の表を生成する。

出力: ROM/disasm_tables.inc(ca65)
- MNEM:   ニーモニック(3 文字 × 56 個)。添字は Operation の宣言順(adc, and, asl, ...)。
- OPMN:   オペコード(0-255)→ ニーモニックの添字。未定義は $FF。
- OPMODE: オペコード → アドレッシングモード番号(AddressingMode の宣言順)。

CPU コアの表が唯一の元データなので、手で写して誤る心配がない。
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
src = (root / "Sources/Core6502/OpcodeTable.swift").read_text()

ops_line = re.search(r"enum Operation: UInt8 \{\n\s+case ([a-z, ]+)\n\s+case illegal", src)
ops = [o.strip() for o in ops_line.group(1).split(",")]
mode_block = re.search(r"enum AddressingMode: UInt8 \{\n(.*?)\n\}", src, re.S).group(1)
modes = [m.strip() for line in mode_block.splitlines() for m in re.sub(r"^\s*case ", "", line).split(",")]
assert len(ops) == 56 and len(modes) == 13, (len(ops), len(modes))

opmn = [0xFF] * 256
opmode = [0] * 256
for m in re.finditer(r"t\[0x([0-9A-F]{2})\] = Instruction\(op: \.(\w+), mode: \.(\w+),", src):
    code = int(m.group(1), 16)
    opmn[code] = ops.index(m.group(2))
    opmode[code] = modes.index(m.group(3))
assert sum(1 for x in opmn if x != 0xFF) == 151

def rows(values, per=16):
    return "\n".join("        .byte " + ", ".join("$%02X" % v for v in values[i:i + per])
                     for i in range(0, len(values), per))

out = [
    "; Tools/gen_disasm_tables.py が生成する。直接編集しない。",
    "; 元データ: Sources/Core6502/OpcodeTable.swift(公式 151 命令)",
    "",
    "; アドレッシングモード番号: " + ", ".join("%d=%s" % (i, m) for i, m in enumerate(modes)),
    "MNEM:",
    "\n".join('        .byte "%s"' % o.upper() for o in ops),
    "",
    "OPMN:",
    rows(opmn),
    "",
    "OPMODE:",
    rows(opmode),
    "",
]
(root / "ROM/disasm_tables.inc").write_text("\n".join(out))
print("ROM/disasm_tables.inc: %d ニーモニック、%d 命令、%d モード" % (len(ops), 151, len(modes)))
