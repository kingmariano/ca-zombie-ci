#!/usr/bin/env bash
# PinkSwap (BSC) L2 Phase-2 heavy job.
# Fresh live-state enumeration at latest block + gate simulations, writes ci-out/.
# Read-only: eth_call/eth_getCode/eth_getLogs only. No transactions. No secrets written.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
python3 ci/run.py 2>&1 | tee ci-out/run.log
exit "${PIPESTATUS[0]}"
