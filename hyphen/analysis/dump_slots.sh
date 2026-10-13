#!/usr/bin/env bash
# dump raw storage slots for the two proxies on a chain. public RPC only.
set -u
CHAIN="${1:-ethereum}"; PROXY="${2:-pool}"; FROM="${3:-0}"; TO="${4:-6}"
case "$CHAIN" in
  ethereum) RPC="https://ethereum-rpc.publicnode.com";;
  polygon)  RPC="https://polygon-bor-rpc.publicnode.com";;
  bsc)      RPC="https://bsc-rpc.publicnode.com";;
  optimism) RPC="https://optimism-rpc.publicnode.com";;
  arbitrum) RPC="https://arbitrum-one-rpc.publicnode.com";;
  avalanche) RPC="https://api.avax.network/ext/bc/C/rpc";;
esac
case "$CHAIN" in
  ethereum|polygon|avalanche) P_POOL=0x2a5c2568b10a0e826bfa892cf21ba7218310180b; P_PROV=0xebab24f13de55789ec1f3ffe99a285754e15f7b9;;
  bsc) P_POOL=0x94d3e62151b12a12a4976f60edc18459538faf08; P_PROV=0x279ac60785a2fcb85550eb243b9a42a543171cc7;;
  optimism|arbitrum) P_POOL=0x856cb5c3cbbe9e2e21293a644aa1f9363cee11e8; P_PROV=0xb4778f5aefeb4605ed96e893417271d4a55e32ee;;
esac
ADDR=$P_POOL; [ "$PROXY" = "prov" ] && ADDR=$P_PROV
for i in $(seq $FROM $TO); do
  slot=$(printf '0x%064x' $i)
  v=$(cast storage "$ADDR" "$slot" --rpc-url "$RPC" 2>&1)
  echo "slot $i ($slot) = $v"
done
