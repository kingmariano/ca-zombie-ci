#!/usr/bin/env bash
# Decompile all fetched bytecode with heimdall into decompiled/<addr>.sol (and print output to logs).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p decompiled logs
for f in code/*.hex; do
  a=$(basename "$f" .hex)
  # skip EOAs / empty
  if [ "$(wc -c < "$f")" -le 3 ]; then echo "$a: EOA/empty"; continue; fi
  if [ -s "decompiled/${a}.sol" ]; then echo "$a: cached"; continue; fi
  echo "== decompiling $a =="
  heimdall decompile "$f" -d -o decompiled -n "${a}" --skip-resolving > "logs/${a}.decompile.log" 2>&1 || echo "  FAILED $a (see log)"
  ls decompiled | grep -i "${a}" || true
done
echo ALLDONE
