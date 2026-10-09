#!/usr/bin/env bash
# Disassemble fetched bytecode into disasm/<addr>.asm via heimdall.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p disasm logs
for f in code/*.hex; do
  a=$(basename "$f" .hex)
  if [ "$(wc -c < "$f")" -le 3 ]; then continue; fi
  if [ -s "disasm/${a}.asm" ]; then echo "$a: cached"; continue; fi
  heimdall disassemble "$f" -o disasm -n "${a}" > "logs/${a}.disasm.log" 2>&1 || echo "FAILED $a"
  echo "$a: $(wc -l < disasm/${a}.asm 2>/dev/null || echo 0) lines"
done
echo DISASMDONE
