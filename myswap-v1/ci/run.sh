#!/usr/bin/env bash
# H-10 mySwap V1 — CI heavy job (read-only Starknet mainnet measurements).
# Runs on GitHub Actions (public repo ca-zombie-ci), finding=myswap-v1.
# No transactions are signed or sent; only JSON-RPC reads and impersonated dry-runs
# via starknet_simulateTransactions (no state change, nothing broadcast).
set -uo pipefail
cd "$(dirname "$0")/.."   # -> myswap-v1/
mkdir -p ci-out
echo "== python: $(python3 --version)"
echo "== folder: $(pwd)"

fail=0

echo "== [1/4] live-state verification (historical + current, read-only)"
if python3 analysis/verify_live.py ci-out/live_state.json; then
  echo "   OK"
else
  echo "   FAILED"; fail=1
fi

echo "== [2/4] impersonated dry-runs (gates)"
if python3 analysis/simulate_gates.py ci-out/simulate_gates.json; then
  echo "   OK"
else
  echo "   FAILED"; fail=1
fi

echo "== [3/4] sibling CL hotfix evidence"
if python3 analysis/cl_hotfix.py ci-out/cl_hotfix.json; then
  echo "   OK"
else
  echo "   FAILED"; fail=1
fi

echo "== [4/4] USD valuation"
if python3 analysis/compute_usd.py ci-out/live_state.json ci-out/usd_summary.json; then
  echo "   OK"
else
  echo "   FAILED"; fail=1
fi

echo "== outputs:"
ls -la ci-out/ || true

# keep the job green if at least the state file exists; record partial failures in the log
if [ ! -s ci-out/live_state.json ]; then
  echo "FATAL: no live_state.json produced"
  exit 1
fi
exit 0
