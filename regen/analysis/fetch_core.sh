#!/usr/bin/env bash
# Fetch core Regen chain state from public LCD endpoints (keyless). Read-only.
set -uo pipefail
LCD="${LCD:-https://regen-api.polkachu.com}"
OUT="$(dirname "$0")/raw"
mkdir -p "$OUT"

get() { # name path
  local name="$1" path="$2"
  curl -s -m 30 "$LCD$path" -o "$OUT/$name.json"
  echo "$name: $(head -c 120 "$OUT/$name.json")"
}

get node_info "/cosmos/base/tendermint/v1beta1/node_info"
get gov_params_v1 "/cosmos/gov/v1/params"
get gov_params_v1beta1 "/cosmos/gov/v1beta1/params"
get staking_pool "/cosmos/staking/v1beta1/pool"
get staking_params "/cosmos/staking/v1beta1/params"
get supply "/cosmos/bank/v1beta1/supply"
get community_pool "/cosmos/distribution/v1beta1/community_pool"
get validators_bonded "/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200"
get module_accounts "/cosmos/auth/v1beta1/module_accounts?pagination.limit=300"
get denoms_metadata "/cosmos/bank/v1beta1/denoms_metadata?pagination.limit=500"
get proposals_v1 "/cosmos/gov/v1/proposals?pagination.limit=100&pagination.reverse=true"
get staking_validators "/cosmos/staking/v1beta1/validators?pagination.limit=500"
