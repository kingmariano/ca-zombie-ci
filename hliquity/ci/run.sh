#!/usr/bin/env bash
# HLiquity CI job — read-only live-state + gate verification on Hedera mainnet.
# Runs inside GitHub Actions (poc.yml). No secrets, no transactions.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[ci] python: $(python3 --version 2>&1)"
echo "[ci] running poc/verify.py (eth_call simulations only; no tx sent)"
python3 poc/verify.py
rc=$?
echo "[ci] verify exit code: $rc"
ls -la ci-out/
exit $rc
