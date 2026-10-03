#!/usr/bin/env bash
# Enumerate Cega V1 product state on Ethereum + Arbitrum. Read-only.
set -uo pipefail
cd "$(dirname "$0")"
OUT=state_evm.txt
ETH="https://ethereum-rpc.publicnode.com"
ARB="${ARB_RPC_URL:-https://arb1.arbitrum.io/rpc}"
ETH_USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
ARB_USDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
ARB_USDCE=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8

{
echo "# Cega V1 EVM state dump — $(date -u +%FT%TZ)"
echo "ETH block: $(cast block-number --rpc-url $ETH)"
echo "ARB block: $(cast block-number --rpc-url $ARB)"
echo

for chain in eth arb; do
  if [ "$chain" = eth ]; then RPC="$ETH"; STATE=0x0730AA138062D8Cc54510aa939b533ba7c30f26B; VIEWER=0x31C73c07Dbd8d026684950b17dD6131eA9BAf2C4; USDC=$ETH_USDC; USDCE=none; else RPC="$ARB"; STATE=0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed; VIEWER=0x8c32a5d9f29da36ed68a9d454eda1b374795b6ca; USDC=$ARB_USDC; USDCE=$ARB_USDCE; fi
  echo "================ CHAIN $chain ================"
  echo "-- state contract $STATE"
  echo "code: $(cast code $STATE --rpc-url $RPC | head -c 20)..."
  echo "USDC bal: $(cast call $USDC 'balanceOf(address)(uint256)' $STATE --rpc-url $RPC 2>/dev/null)"
  [ "$USDCE" != none ] && echo "USDC.e bal: $(cast call $USDCE 'balanceOf(address)(uint256)' $STATE --rpc-url $RPC 2>/dev/null)"
  echo "-- viewer $VIEWER"
  echo "USDC bal: $(cast call $USDC 'balanceOf(address)(uint256)' $VIEWER --rpc-url $RPC 2>/dev/null)"
  names=$(cast call $STATE "getProductNames()(string[])" --rpc-url "$RPC" | tr -d '[]"' | tr ',' '\n')
  echo
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    addr=$(cast call $STATE "products(string)(address)" "$n" --rpc-url "$RPC" 2>/dev/null)
    echo "### product=$n addr=$addr"
    if [ "$addr" != "0x0000000000000000000000000000000000000000" ]; then
      code=$(cast code $addr --rpc-url $RPC | head -c 6)
      echo "code=$code USDC=$(cast call $USDC 'balanceOf(address)(uint256)' $addr --rpc-url $RPC 2>/dev/null) USDCe=$([ "$USDCE" != none ] && cast call $USDCE 'balanceOf(address)(uint256)' $addr --rpc-url $RPC 2>/dev/null)"
      echo "sumVaultUnderlyingAmounts=$(cast call $addr 'sumVaultUnderlyingAmounts()(uint256)' --rpc-url $RPC 2>/dev/null)"
      echo "queuedDepositsTotalAmount=$(cast call $addr 'queuedDepositsTotalAmount()(uint256)' --rpc-url $RPC 2>/dev/null)"
      echo "queuedWithdrawalsTotalAmount=$(cast call $addr 'queuedWithdrawalsTotalAmount()(uint256)' --rpc-url $RPC 2>/dev/null)"
      echo "totalSupply=$(cast call $addr 'totalSupply()(uint256)' --rpc-url $RPC 2>/dev/null)"
      echo "underlyingToken=$(cast call $addr 'underlyingToken()(address)' --rpc-url $RPC 2>/dev/null)"
      echo "owner=$(cast call $addr 'owner()(address)' --rpc-url $RPC 2>/dev/null)"
      echo "manager=$(cast call $addr 'manager()(address)' --rpc-url $RPC 2>/dev/null)"
      echo "paused=$(cast call $addr 'paused()(bool)' --rpc-url $RPC 2>/dev/null)"
    fi
  done <<< "$names"
  echo
done
} > "$OUT" 2>&1
cat "$OUT"
