#!/bin/bash
# 6502 アセンブリ(ca65 構文)を、$0300 に置く生のバイナリにする(cc65 が必要)。
# 使い方: Tools/assemble.sh tutorial/counter.s [出力.bin]
set -euo pipefail
if [ $# -lt 1 ]; then
    echo "使い方: $0 source.s [output.bin]" >&2
    exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$1"
out="${2:-${src%.s}.bin}"
obj="$(mktemp -t glow65).o"
trap 'rm -f "$obj"' EXIT
ca65 -o "$obj" "$src"
ld65 -C "$root/ROM/user.cfg" -o "$out" "$obj"
echo "$out: $(wc -c < "$out" | tr -d ' ') bytes (load at \$0300)"
