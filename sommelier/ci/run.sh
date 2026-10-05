#!/usr/bin/env bash
# C2-08 Sommelier — CI evidence job (read-only, public endpoints only).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[ci] sommelier evidence job starting $(date -u +%FT%TZ)"
echo "[ci] python: $(python3 --version 2>&1)"
python3 ci/collect_live.py > ci-out/collect.log 2>&1 || { echo "[ci] collect_live.py FAILED"; tail -50 ci-out/collect.log; }
python3 ci/cost_model.py > ci-out/model.log 2>&1 || { echo "[ci] cost_model.py FAILED"; tail -50 ci-out/model.log; }
echo "[ci] outputs:"
ls -la ci-out/
echo "----- collect.log -----"; tail -40 ci-out/collect.log 2>/dev/null || true
echo "----- model.log -----"; tail -40 ci-out/model.log 2>/dev/null || true
