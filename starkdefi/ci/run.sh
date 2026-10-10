#!/usr/bin/env bash
# StarkDeFi (C2-48) CI verification — read-only, keyless Starknet RPC.
# Re-runs the decisive checks and writes results to ci-out/ (uploaded as artifact).
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== StarkDeFi CI verify =="
python3 --version
python3 analysis/ci_verify.py
echo "== done; ci-out: =="
ls -la ci-out/
