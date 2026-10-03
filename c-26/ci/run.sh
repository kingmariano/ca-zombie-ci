#!/usr/bin/env bash
# C-26 heavy job (runs on GitHub Actions from c-26/).
# 1) exhaustive on-chain enumeration of Safes with the module enabled + balances + prices
# 2) supplementary Base/Arbitrum module-state + balance check
# Non-fatal: the foundry exploit test runs in the next workflow step regardless.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> c-26/
mkdir -p ci-out

echo "== C-26 enumeration =="
python3 ci/enumerate.py 2>&1 | tee ci-out/enumerate.log || echo "WARN: enumerate.py failed"

echo "== C-26 cross-chain supplement =="
python3 ci/crosschain.py 2>&1 | tee ci-out/crosschain.log || echo "WARN: crosschain.py failed"

# ship key evidence into the artifact
for f in analysis/safe_verification.json analysis/events_state.json analysis/attacker_drain_calls.json \
         analysis/exhaustive_enabled_check.json analysis/drainable_now.json; do
  [ -f "$f" ] && cp "$f" ci-out/ 2>/dev/null
done

echo "== C-26 done =="
ls -la ci-out/
exit 0
