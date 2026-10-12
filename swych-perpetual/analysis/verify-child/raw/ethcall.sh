#!/usr/bin/env bash
# eth_call helper: prints JSON-RPC result/error verbatim. No secrets used.
# usage: ethcall.sh <rpc> <block_hex_or_dec> <to> <data> [from]
RPC="$1"; BLK="$2"; TO="$3"; DATA="$4"; FROM="${5:-0x1111111111111111111111111111111111111111}"
BLKHEX=$(printf '0x%x' "$BLK" 2>/dev/null || echo "$BLK")
curl -s -A "Mozilla/5.0 (X11; Linux x86_64)" -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_call\",\"params\":[{\"to\":\"$TO\",\"data\":\"$DATA\",\"from\":\"$FROM\"},\"$BLKHEX\"]}" \
  "$RPC" | jq -c '{result:.result, error:.error}'
