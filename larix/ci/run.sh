#!/usr/bin/env bash
# C2-25 Larix proof job (read-only; keyless public RPC; no secrets).
set -euo pipefail
cd "$(dirname "$0")/.."   # folder root (larix/)

echo "[c2-25] installing solders..."
python3 -m pip install --quiet --disable-pip-version-check solders

mkdir -p ci-out
echo "[c2-25] running live read-only simulations (no tx signed/sent)..."
python3 ci/run_sims.py ci-out | tee ci-out/local-run.log

echo "[c2-25] done. results in ci-out/"
ls -la ci-out/
