#!/usr/bin/env bash
# Taiga Acala (L2 Phase-2) heavy job: state snapshot + gate math + tDOT holder scan.
# Read-only. Public RPC only. Writes results to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[taiga-ci] start $(date -u +%FT%TZ)"
python3 ci/taiga_ci.py 2>&1 | tee ci-out/ci-run.log
echo "[taiga-ci] done rc=$? $(date -u +%FT%TZ)"
