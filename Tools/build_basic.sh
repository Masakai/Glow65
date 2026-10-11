#!/bin/bash
# Microsoft BASIC を ca65 用に変換してビルドし、ROM/basic/build/basic.bin を生成する(cc65 が必要)。
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Tools/convert_m6502.py
cd ROM/basic/build
ca65 -i -I .. -l m6502.lst -o m6502.o m6502.s
ld65 -C ../basic.cfg -m m6502.map -Ln m6502.lbl -o basic.bin m6502.o
ls -l basic.bin
