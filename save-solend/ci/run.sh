#!/usr/bin/env bash
# CI job for C2-24 / save-solend: read-only on-chain proof via Solana simulateTransaction.
# Public RPC only; no keys; writes results to ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."

echo "[ci] save-solend proof job starting $(date -u +%FT%TZ)"
python3 --version
python3 ci/prove.py
echo "[ci] proof job done $(date -u +%FT%TZ)"
ls -la ci-out/
