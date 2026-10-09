#!/usr/bin/env bash
# C2-35 Jackal — CI evidence job (public endpoints only; no secrets used or printed).
# Collects live jackal-1 state + Osmosis JKL liquidity, computes the capture/liquidity model.
# Outputs to ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[jackal-ci] start $(date -u +%FT%TZ)"
python3 --version
python3 ci/evidence.py --out ci-out --gauge-cap 2000 --workers 24
rc=$?
echo "[jackal-ci] evidence.py rc=$rc"
echo "---- ci-out ----"
find ci-out -maxdepth 2 -type f | sort | head -50
if [ -f ci-out/model.md ]; then echo "---- model.md ----"; cat ci-out/model.md; fi
exit $rc
