#!/usr/bin/env bash
# Read-only helpers. Public keyless RPCs only (no secrets).
# usage: rpc.sh <chain> <method> <params-json>
CHAIN="$1"; METHOD="$2"; PARAMS="${3:-[]}"
case "$CHAIN" in
  ethereum) RPC="https://ethereum-rpc.publicnode.com";;
  polygon)  RPC="https://polygon-bor-rpc.publicnode.com";;
  bsc)      RPC="https://bsc-rpc.publicnode.com";;
  optimism) RPC="https://optimism-rpc.publicnode.com";;
  arbitrum) RPC="https://arbitrum-one-rpc.publicnode.com";;
  avalanche) RPC="https://api.avax.network/ext/bc/C/rpc";;
  base)     RPC="https://base-rpc.publicnode.com";;
  fantom)   RPC="https://fantom-rpc.publicnode.com";;
  *) echo "unknown chain $CHAIN" >&2; exit 1;;
esac
curl -s -m 25 -X POST -H 'Content-Type: application/json' -H 'User-Agent: Mozilla/5.0' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$METHOD\",\"params\":$PARAMS}" "$RPC"
