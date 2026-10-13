#!/bin/bash
# GAME65G の ROM をビルドして ROM/game65g.bin を生成する(cc65 が必要)。
set -euo pipefail
cd "$(dirname "$0")/../ROM/game65g"
ca65 -l game65g.lst -o game65g.o game65g.s
ld65 -C game65g.cfg -m game65g.map -o ../game65g.bin game65g.o
rm -f game65g.o
ls -l ../game65g.bin
