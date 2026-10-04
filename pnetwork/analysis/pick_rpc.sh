#!/usr/bin/env bash
# RPC helper: pick a working Ethereum RPC from .env that supports eth_call; fallback public.
set -uo pipefail
source /home/heisenberg/CA/.env
CANDS=("$BLOCKPI_RPC_URL" "$NODEREAL_ETH_RPC_URL" "$RPC_URL" "https://ethereum-rpc.publicnode.com" "https://eth.drpc.org" "https://1rpc.io/eth")
for c in "${CANDS[@]}"; do
  [ -z "$c" ] && continue
  out=$(curl -s -m 10 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0xdAC17F958D2ee523a2206206994597C13D831ec7","data":"0x06fdde03"},"latest"]}' "$c" 2>/dev/null)
  if echo "$out" | grep -q '"result"'; then
    echo "$c"
    exit 0
  fi
done
echo "https://ethereum-rpc.publicnode.com"
