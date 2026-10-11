#!/bin/bash
# モニタ ROM をビルドして ROM/monitor.bin を生成する(cc65 が必要)。
set -euo pipefail
cd "$(dirname "$0")/../ROM"
ca65 -l monitor.lst -o monitor.o monitor.s
ld65 -C monitor.cfg -m monitor.map -o monitor.bin monitor.o
rm -f monitor.o
ls -l monitor.bin
