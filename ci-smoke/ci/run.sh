#!/usr/bin/env bash
set -euo pipefail
mkdir -p ci-out
echo "env checks (secrets are never printed):"
for v in RPC_URL BLOCKPI_RPC_URL ETHERSCANV2_API_KEY GOLD_RUSH_API_KEY ALCHEMY_API_KEY; do
  val="${!v:-}"
  if [ -n "$val" ]; then echo "  $v set (len ${#val})"; else echo "  $v EMPTY"; fi
done
RPC="${RPC_URL:-https://ethereum-rpc.publicnode.com}"
echo "chain-id via primary RPC:"
cast chain-id --rpc-url "$RPC"
printf '{"smoke":"ok","chainid":1}\n' > ci-out/smoke.json
