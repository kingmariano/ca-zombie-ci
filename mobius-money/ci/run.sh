#!/usr/bin/env bash
# Mobius Money — heavy CI job (runs on GitHub Actions, keyless public RPCs, read-only).
# 1) verify deployed pool/library bytecode vs vendored repo artifacts
# 2) full Ubeswap pair scan for all Mobius-pool tokens (market depth)
# 3) fresh on-chain valuation of all pools with correct token identities
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[mobius] pwd=$(pwd)"
python3 --version
mkdir -p ci-out
echo "[mobius] === code verification ==="
python3 analysis/verify_code.py 2>&1 | tail -40
echo "[mobius] === market scan ==="
python3 ci/market_scan.py 2>&1 | tail -20
echo "[mobius] === fresh valuation ==="
python3 analysis/valuation.py 2>&1 | tail -30
cp -f analysis/valuation.json ci-out/valuation.json 2>/dev/null || true
echo "[mobius] === realizability-adjusted valuation ==="
python3 analysis/realizable.py 2>&1 | tail -8
cp -f analysis/realizable.json ci-out/realizable.json 2>/dev/null || true
cp -f analysis/realizable.md ci-out/realizable.md 2>/dev/null || true
echo "[mobius] listing ci-out:"
ls -la ci-out/
echo "[mobius] done"
