#!/usr/bin/env bash
# Pull core Stride chain state from public LCDs (read-only).
set -uo pipefail
OUT=raw
B1="https://rest.cosmos.directory/stride"
B2="https://stride-api.polkachu.com"
get() { # $1=name $2=path
  for B in "$B1" "$B2"; do
    code=$(curl -s -m 20 -o "$OUT/$1.json" -w "%{http_code}" "$B$2" || true)
    if [ "$code" = "200" ]; then echo "OK  $1 <- $B$2"; return 0; fi
  done
  echo "FAIL $1 ($code)"; return 1
}
get height      "/cosmos/base/tendermint/v1beta1/blocks/latest"
get gov_params  "/cosmos/gov/v1/params"
get gov_params_v1b "/cosmos/gov/v1beta1/params"
get staking_pool "/cosmos/staking/v1beta1/pool"
get staking_params "/cosmos/staking/v1beta1/params"
get community_pool "/cosmos/distribution/v1beta1/community_pool"
get supply      "/cosmos/bank/v1beta1/supply?pagination.limit=500"
get validators  "/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200"
get proposals   "/cosmos/gov/v1/proposals?pagination.limit=30&pagination.reverse=true"
get module_accounts "/cosmos/auth/v1beta1/module_accounts?pagination.limit=300"
get host_zones  "/stride/stakeibc/host_zone"
get upgrade_plan "/cosmos/upgrade/v1beta1/current_plan"
get mint_params "/cosmos/mint/v1beta1/params"
get mint_inflation "/cosmos/mint/v1beta1/inflation"
