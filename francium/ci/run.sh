#!/usr/bin/env bash
# CI heavy job for finding H-29 (Francium, Solana). Read-only: RPC reads + simulateTransaction only.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[ci] start:"; date -u

# --- 1. live-state verification (programs, authorities, vault balances) ---
python3 analysis/verify_state.py 2>&1 | tee ci-out/state_summary.log || echo "[ci] verify_state failed"

# --- 2. npm-free RPC simulations proving the swapAndWithdraw authorization gates ---
python3 analysis/simulate_gate.py 2>&1 | tee ci-out/sim_gate.log || echo "[ci] simulate_gate failed"

# --- 3. optional Node cross-check if deps are present (skipped otherwise) ---
if [ -d poc-sim/node_modules ]; then
  (cd poc-sim && node sim_final.js 2>&1 | tee ../ci-out/sim_final_node.log) || true
fi
echo "[ci] done"
