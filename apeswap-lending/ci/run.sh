#!/usr/bin/env bash
# ApeSwap Lending (C2-16) heavy CI job — read-only chain scan.
# Runs before `forge test`; results in ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[apeswap] start $(date -u +%FT%TZ)"
python3 --version
python3 ci/scan.py
rc=$?
echo "[apeswap] scan exit=$rc"
exit $rc
