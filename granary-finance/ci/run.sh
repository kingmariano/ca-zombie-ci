#!/usr/bin/env bash
# Granary Finance — heavy enumeration job (runs on GitHub Actions).
# Re-runs the borrower/HF scans using CI RPCs and writes results to ci-out/.
# Read-only. No secrets are written to output.
set -uo pipefail
cd "$(dirname "$0")/.."

mkdir -p ci-out

# Map CI RPC env vars onto the script's <CHAIN>_RPC_URL overrides.
export ETHEREUM_RPC_URL="${FORK_RPC_URL:-${RPC_URL:-}}"
export OPTIMISM_RPC_URL="${OP_RPC_URL:-}"
export ARBITRUM_RPC_URL="${ARB_RPC_URL:-}"
export BSC_RPC_URL="${BSC_RPC_URL:-}"
export BASE_RPC_URL="${BASE_RPC_URL:-}"
# metis/avalanche have no CI-provided RPC; script falls back to public keyless endpoints.

echo "== chains to scan =="
echo "ethereum: ${ETHEREUM_RPC_URL:+set}"
echo "optimism: ${OPTIMISM_RPC_URL:+set}"
echo "arbitrum: ${ARBITRUM_RPC_URL:+set}"
echo "bsc: ${BSC_RPC_URL:+set}"
echo "base: ${BASE_RPC_URL:+set}"

for ch in ethereum optimism arbitrum bsc base metis avalanche; do
  echo "=== scanning $ch ==="
  python3 -u analysis/enumerate_borrowers.py "$ch" 2>&1 | tail -40
  cp -f "analysis/borrowers-$ch.json" "ci-out/" 2>/dev/null || echo "no borrowers-$ch.json"
done

echo "=== re-verify reserve state (fresh blocks) ==="
python3 -u analysis/probe_state.py ethereum optimism metis arbitrum avalanche bsc base fantom 2>&1 | tail -120
cp -f analysis/state-*.json ci-out/ 2>/dev/null || true

echo "=== live value table ==="
python3 analysis/live_value.py 2>&1 | tail -80 > ci-out/live-value.txt
cp -f analysis/live-value.json ci-out/ 2>/dev/null || true

echo "done"
