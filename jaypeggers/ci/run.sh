#!/usr/bin/env bash
# Jaypeggers heavy job (CI): reproducible live-state snapshot + staker censuses.
# Read-only; no secrets are printed or written.
set -uo pipefail
cd "$(dirname "$0")/.."

mkdir -p ci-out

# Pick a working RPC that supports eth_call: prefer public endpoints, then the
# injected one (some keyed endpoints, e.g. flashbots protect, reject eth_call).
RPC=""
for cand in "https://ethereum-rpc.publicnode.com" "https://eth.drpc.org" "${RPC_URL:-}"; do
  [ -z "$cand" ] && continue
  if cast call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "totalSupply()(uint256)" \
        --rpc-url "$cand" >/dev/null 2>&1; then RPC="$cand"; break; fi
done
if [ -z "$RPC" ]; then echo "[ci] no working RPC with eth_call support"; exit 1; fi

BLK=$(cast block-number --rpc-url "$RPC")
echo "[ci] using block $BLK (rpc URL not printed)"
export RPC_URL="$RPC"
export BLOCK="$BLK"

python3 analysis/collect_state.py ci-out/live-state.json

echo "[ci] staker census v1 (JAY/USDC LP staking, ETH rewards)"
python3 analysis/staker_census.py \
  0x112E9FdAd728aDFBb1CE407a9CFa9339E1C6E130 \
  analysis/all_staker_candidates.txt \
  ci-out/census-v1.json "" 0x399080ec 0xc00007b0 || echo "[ci] v1 census failed"

echo "[ci] staker census v2 (jUSDC/WETH LP staking, USDC rewards)"
python3 analysis/staker_census.py \
  0xF70C2657C4135C2cE81977C32F7bC1E012A7226d \
  analysis/v2_staker_candidates.txt \
  ci-out/census-v2.json "" 0x399080ec 0xc00007b0 || echo "[ci] v2 census failed"

echo "[ci] out files:"
ls -la ci-out
