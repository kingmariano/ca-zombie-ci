#!/usr/bin/env bash
# Read-only fetch of Nolus (pirin-1) public chain state via keyless public LCD endpoints.
# Saves raw JSON to analysis/raw/. No secrets, no writes to chain.
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p raw
LCDS=("https://lcd.nolus.network" "https://nolus.api.liveraven.net" "https://nolus-api.polkachu.com" "https://nolus-api.cogwheel.zone")
get() { # get <name> <path>
  local name="$1" path="$2" out="raw/$1.json"
  for base in "${LCDS[@]}"; do
    if curl -sf --max-time 25 -H 'User-Agent: zombie-research/1.0' "$base$path" -o "$out.tmp"; then
      mv "$out.tmp" "$out"; echo "OK  $name  <- $base"; return 0
    fi
  done
  echo "FAIL $name"; return 1
}
get node_info          "/cosmos/base/tendermint/v1beta1/node_info"
get gov_params         "/cosmos/gov/v1/params"
get gov_props          "/cosmos/gov/v1/proposals?pagination.limit=100&pagination.reverse=true"
get staking_pool       "/cosmos/staking/v1beta1/pool"
get staking_params     "/cosmos/staking/v1beta1/params"
get validators         "/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200"
get delegations_tot    "/cosmos/staking/v1beta1/delegations"
get community_pool     "/cosmos/distribution/v1beta1/community_pool"
get module_accounts    "/cosmos/auth/v1beta1/module_accounts?pagination.limit=200"
get supply             "/cosmos/bank/v1beta1/supply?pagination.limit=500"
get mint_params        "/cosmos/mint/v1beta1/params"
get inflation          "/cosmos/mint/v1beta1/inflation"
get distr_params       "/cosmos/distribution/v1beta1/params"
get slashing_params    "/cosmos/slashing/v1beta1/params"
get latest_block       "/cosmos/base/tendermint/v1beta1/blocks/latest"
echo "done"
