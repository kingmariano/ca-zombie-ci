#!/usr/bin/env bash
# Read-only live-state dump for Hyphen. Public keyless RPCs only.
set -u
cd "$(dirname "$0")"

declare -A RPC
RPC[ethereum]="https://ethereum-rpc.publicnode.com"
RPC[polygon]="https://polygon-bor-rpc.publicnode.com"
RPC[bsc]="https://bsc-rpc.publicnode.com"
RPC[optimism]="https://optimism-rpc.publicnode.com"
RPC[arbitrum]="https://arbitrum-one-rpc.publicnode.com"
RPC[avalanche]="https://api.avax.network/ext/bc/C/rpc"

declare -A PROV POOL
PROV[ethereum]=0xebab24f13de55789ec1f3ffe99a285754e15f7b9
POOL[ethereum]=0x2a5c2568b10a0e826bfa892cf21ba7218310180b
PROV[polygon]=0xebab24f13de55789ec1f3ffe99a285754e15f7b9
POOL[polygon]=0x2a5c2568b10a0e826bfa892cf21ba7218310180b
PROV[avalanche]=0xebab24f13de55789ec1f3ffe99a285754e15f7b9
POOL[avalanche]=0x2a5c2568b10a0e826bfa892cf21ba7218310180b
PROV[bsc]=0x279ac60785a2fcb85550eb243b9a42a543171cc7
POOL[bsc]=0x94d3e62151b12a12a4976f60edc18459538faf08
PROV[optimism]=0xb4778f5aefeb4605ed96e893417271d4a55e32ee
POOL[optimism]=0x856cb5c3cbbe9e2e21293a644aa1f9363cee11e8
PROV[arbitrum]=0xb4778f5aefeb4605ed96e893417271d4a55e32ee
POOL[arbitrum]=0x856cb5c3cbbe9e2e21293a644aa1f9363cee11e8

out="$1"; : > "$out"
for c in ethereum polygon avalanche bsc optimism arbitrum; do
  r=${RPC[$c]}; p=${POOL[$c]}; lp=${PROV[$c]}
  bn=$(cast block-number --rpc-url "$r")
  echo "=== chain=$c block=$bn pool=$p prov=$lp" >> "$out"
  for fn in "owner()(address)" "paused()(bool)" "getExecutorManager()(address)" "tokenManager()(address)" "liquidityProviders()(address)" "baseGas()(uint256)"; do
    v=$(cast call "$p" "$fn" --rpc-url "$r" 2>&1 | head -1)
    echo "pool.$fn = $v" >> "$out"
  done
  for fn in "owner()(address)" "paused()(bool)" "lpToken()(address)" "tokenManager()(address)" "liquidityPool()(address)" "whiteListPeriodManager()(address)" "BASE_DIVISOR()(uint256)"; do
    v=$(cast call "$lp" "$fn" --rpc-url "$r" 2>&1 | head -1)
    echo "prov.$fn = $v" >> "$out"
  done
  nat=$(cast balance "$p" --rpc-url "$r" 2>&1 | head -1)
  echo "pool.native_balance_wei = $nat" >> "$out"
done
