#!/usr/bin/env bash
# CI custom job: re-run the AuroraSwap read-only state scan (public RPC only) and
# copy evidence into ci-out/. No secrets, no transactions.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out
echo "[auroraswap-ci] python scan"
python3 analysis/scan_pairs.py 2>&1 | tee ci-out/scan_console.txt
cp analysis/pairs_scan.json ci-out/pairs_scan.json 2>/dev/null || true
cp analysis/tokens_meta.json ci-out/tokens_meta.json 2>/dev/null || true
echo "[auroraswap-ci] done"
ls -la ci-out
