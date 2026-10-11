#!/usr/bin/env bash
# JediSwap V1 deep-dive — CI heavy job (read-only; public keyless RPCs only; no secrets).
# Runs from the finding folder (workflow invokes: bash ci/run.sh).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p ci-out

echo "=== [1/3] live state verification ==="
python3 ci/ci_verify.py 2>&1 | tee ci-out/ci_verify.log

echo "=== [2/3] read-only simulations ==="
python3 ci/ci_sims.py 2>&1 | tee ci-out/ci_sims.log

echo "=== [3/3] class-hash verification (compile jediswaplabs/JediSwap @ 11b4414) ==="
bash ci/classhash.sh

echo "=== CI JOB DONE ==="
exit 0
