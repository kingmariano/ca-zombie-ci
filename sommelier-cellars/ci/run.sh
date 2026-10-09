#!/usr/bin/env bash
# C2-28 Sommelier cellars / gravity module dust — CI evidence job.
# Runs on the public ca-zombie-ci runner. Read-only public LCD/RPC/Blockscout/DefiLlama
# queries only; no secrets are used or printed.
set -uo pipefail
cd "$(dirname "$0")/.."          # finding folder (sommelier-cellars/)

echo "[ci] C2-28 sommelier-cellars — start $(date -u +%FT%TZ)"
echo "[ci] python: $(python3 --version 2>&1)"

python3 ci/evidence.py 2>&1 | tee ci-out/evidence.log

echo "[ci] artifact listing:"
find ci-out -type f | sort

if [ -f ci-out/summary_ci.json ]; then
  echo "[ci] OK"
  exit 0
else
  echo "[ci] ERROR: ci-out/summary_ci.json missing" >&2
  exit 1
fi
