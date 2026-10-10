#!/usr/bin/env bash
# H2-08 IncrementFi CI job: live read-only re-verification of the seize() gate + full
# liquidation-surface snapshot. Public Flow mainnet endpoints only; no secrets.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root (incrementfi/)
mkdir -p ci-out
echo "== gate tests =="
python3 analysis/ci_gate_tests.py | tee ci-out/gate_tests.txt
echo "== full enumeration (markets, borrowers, cross-market liquidity) =="
python3 analysis/enumerate_borrowers.py | tee ci-out/enumeration.txt
cp analysis/raw/underwater.json analysis/raw/liquidity.json analysis/raw/borrowers.json ci-out/ 2>/dev/null || true
echo "== per-account positions + liquidation profit model =="
python3 analysis/positions_run.py | tee ci-out/positions.txt
cp analysis/raw/positions.json analysis/raw/liquidation_profit.json ci-out/ 2>/dev/null || true
echo "== done =="
ls -la ci-out/
