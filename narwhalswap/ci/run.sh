#!/usr/bin/env bash
# CI heavy/verification job for the Narwhalswap deep-dive.
# 1) live-state re-verification (read-only RPC reads) -> ci-out/live-state.json
# 2) (forge test runs automatically afterwards by the workflow)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== live state dump =="
python3 ci/live_state.py

echo "== pair bytecode integrity check =="
python3 ci/integrity.py || echo "integrity check failed (non-fatal)"

echo "== done =="
ls -la ci-out/
