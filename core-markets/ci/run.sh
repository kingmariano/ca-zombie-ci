#!/usr/bin/env bash
# core-markets/ci/run.sh — light, read-only on-chain re-verification of the Core Markets
# live state (Blast). Writes results to ci-out/. No secrets required.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[ci] core-markets live-state verification @ $(date -u +%FT%TZ)"
python3 ci/verify_state.py 2>&1 | tee ci-out/verify_state.log
echo "[ci] done (exit $?)"
