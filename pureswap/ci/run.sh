#!/usr/bin/env bash
# PureSwap (BSC) zombie audit — heavy CI job (runs on GitHub Actions).
# Read-only RPC calls only. No secrets are written to files (BSC_RPC_URL stays in env).
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root

echo "[pureswap] ci scan start $(date -u +%FT%TZ)"
python3 --version
python3 ci/scan.py
RC=$?
echo "[pureswap] scan.py rc=$RC"
ls -la ci-out/ 2>/dev/null || true
echo "[pureswap] ci scan end $(date -u +%FT%TZ)"
exit $RC
