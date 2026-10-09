#!/usr/bin/env bash
# C2-34 dydx-chain — CI verification job (read-only, public endpoints only).
# Re-derives: live node version + ibc-go replace evidence, fork fix markers,
# gov params/pools, module balances, DYDX price, IBC channel counts.
# Outputs to ci-out/. Never prints or writes secrets.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "=== C2-34 dydx-chain verification $(date -u +%FT%TZ) ===" | tee ci-out/runner.log
python3 ci/verify.py 2>&1 | tee -a ci-out/runner.log
rc=${PIPESTATUS[0]}
echo "=== verify.py exit: $rc ===" | tee -a ci-out/runner.log
ls -la ci-out/ | tee -a ci-out/runner.log
exit $rc
