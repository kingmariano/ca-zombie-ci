#!/usr/bin/env bash
# C2-03 Lybra V1 — custom CI heavy job (runs from lybra-v1/ in GitHub Actions).
# Read-only: refreshes live on-chain state at the CI tip and writes ci-out/ artifacts.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "== C2-03 Lybra V1 live-state refresh =="
python3 ci/fetch_live_state.py || echo "WARN: live-state refresh failed (tests still run)"

echo "== ci-out contents =="
ls -la ci-out/ || true
