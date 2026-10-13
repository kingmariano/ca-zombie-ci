#!/usr/bin/env bash
# SharkSwap DEX (Base) heavy CI job — read-only live re-check. No secrets written.
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[sharkswap-dex] start $(date -u +%FT%TZ)"
python3 --version
python3 ci/recheck.py
RC=$?
echo "[sharkswap-dex] recheck rc=$RC"
ls -la ci-out/ 2>/dev/null || true
echo "[sharkswap-dex] end $(date -u +%FT%TZ)"
exit $RC
