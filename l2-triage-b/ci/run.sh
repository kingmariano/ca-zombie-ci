#!/usr/bin/env bash
# l2-triage-b heavy custody enumeration (runs on GitHub Actions).
# Keyless public RPCs only; read-only. Results -> ci-out/
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[l2b] pwd=$(pwd)"
python3 --version
mkdir -p ci-out
# 1) full screen (skip if results.json already present from the local run)
if [ ! -s ci-out/results.json ]; then
  echo "[l2b] full enumeration"
  python3 ci/enumerate.py 2>&1 | tee -a ci-out/run.log
else
  echo "[l2b] ci-out/results.json present ($(wc -c < ci-out/results.json) bytes) - skipping full pass"
fi
# 2) deep pass for factories whose pair lists exceeded the sampling cap
echo "[l2b] deep pass: leetswap + lfgswap-ethereumpow (all pairs)"
L2B_ONLY=leetswap,lfgswap-ethereumpow L2B_MAX_PAIRS=6000 L2B_OUT=deep-results.json \
  python3 ci/enumerate.py 2>&1 | tee -a ci-out/run.log
echo "[l2b] exit=$?"
ls -la ci-out/
