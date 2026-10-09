#!/usr/bin/env bash
# Read-only LCD fetches for dydx gov-economics analysis (zombie-hunt II).
# Public endpoints only. No transactions, no signing, no keys.
set -uo pipefail
OUT=/home/heisenberg/CA/dydx-chain/analysis/raw
mkdir -p "$OUT"
MANIFEST="$OUT/manifest.tsv"
touch "$MANIFEST"
BASES=(https://dydx-dao-api.polkachu.com https://dydx-rest.publicnode.com https://rest-dydx.cosmostation.io)

fetch() {
  local path="$1" fname="$2" base code
  for base in "${BASES[@]}"; do
    code=$(curl -sS --max-time 25 -o "$OUT/.$fname.tmp" -w '%{http_code}' "$base$path" 2>/dev/null) || continue
    if [ "$code" = "200" ] && jq -e 'has("code") and (.code != 0)' "$OUT/.$fname.tmp" >/dev/null 2>&1; then
      continue
    fi
    if [ "$code" = "200" ] && jq -e . "$OUT/.$fname.tmp" >/dev/null 2>&1; then
      mv "$OUT/.$fname.tmp" "$OUT/$fname"
      printf '%s\t%s\t%s\t%s\n' "$fname" "$base" "$path" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$MANIFEST"
      echo "OK   $fname <- $base"
      return 0
    fi
  done
  rm -f "$OUT/.$fname.tmp"
  echo "FAIL $fname ($path)"
  return 1
}

# ---- chain state / height anchors ----
fetch "/cosmos/base/tendermint/v1beta1/blocks/latest" "latest_block_start.json"
fetch "/cosmos/base/tendermint/v1beta1/node_info" "node_info.json"

# ---- governance params ----
fetch "/cosmos/gov/v1/params/tallying" "gov_params_tallying.json"
fetch "/cosmos/gov/v1/params/voting" "gov_params_voting.json"
fetch "/cosmos/gov/v1/params/deposit" "gov_params_deposit.json"
fetch "/cosmos/gov/v1/proposals?proposal_status=PROPOSAL_STATUS_VOTING_PERIOD&pagination.limit=50" "gov_proposals_voting.json"

# ---- staking ----
fetch "/cosmos/staking/v1beta1/pool" "staking_pool.json"
fetch "/cosmos/staking/v1beta1/params" "staking_params.json"
fetch "/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=100" "validators_bonded.json"

# ---- bank / supply ----
fetch "/cosmos/bank/v1beta1/supply/by_denom?denom=adydx" "supply_adydx.json"
fetch "/cosmos/bank/v1beta1/supply?pagination.limit=1000" "supply_all.json"

# ---- distribution community pool ----
fetch "/cosmos/distribution/v1beta1/community_pool" "community_pool.json"

# ---- module accounts ----
fetch "/cosmos/auth/v1beta1/module_accounts?pagination.limit=200" "module_accounts.json"

# ---- IBC denom traces ----
fetch "/ibc/apps/transfer/v1/denom_traces?pagination.limit=1000" "denom_traces_all.json"
fetch "/ibc/apps/transfer/v1/denom_traces/8E27BA2D5493AF5636760E354E46004562C46AB7EC0CC4C1CA14E9E20E2545B5" "denom_trace_8E27BA2D.json"
fetch "/ibc/apps/transfer/v1/denom_traces/15781DDDCD499274C978F31A0DBD6DA93D8EE0F7200891898549AFC7C5B5948A" "denom_trace_15781DDD.json"
fetch "/ibc/apps/transfer/v1/denom_traces/AD9B9B572C8099DF19DC6233FAC79C0AFD20972864F258439C2A96ED7FC1B903" "denom_trace_AD9B9B57.json"
fetch "/ibc/apps/transfer/v1/denom_traces/E5DA7F807E9588AA76C33C1E0A91B5D34076F7D6FA170297DFD076EB14D36C0A" "denom_trace_E5DA7F80.json"

# ---- per-module-account balances (all module accounts + named accounts) ----
NAMED="dydx15ztc7xy42tn2ukkc0qjthkucw9ac63pgp70urn
dydx16wrau2x4tsg033xfrrdpae6kxfn9kyuerr5jjp
dydx1c7ptc87hkd54e3r7zjy92q29xkq7t79w64slrq
dydx1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8wx2cfg
dydx1zlefkpe3g0vvm9a4h0jf9000lmqutlh9jwjnsv
dydx18tkxrnrkqc2t0lr3zxr5g6a4hdvqksylxqje4r
dydx1wxje320an3karyc6mjw4zghs300dmrjkwn7xtk
dydx1ltyc6y4skclzafvpznpt2qjwmfwgsndp458rmp"

MODADDRS=""
if [ -s "$OUT/module_accounts.json" ]; then
  MODADDRS=$(jq -r '.accounts[]?.base_account.address // empty' "$OUT/module_accounts.json" | sort -u)
fi

ALLADDRS=$(printf '%s\n%s\n' "$NAMED" "$MODADDRS" | sed '/^$/d' | sort -u)
for addr in $ALLADDRS; do
  fetch "/cosmos/bank/v1beta1/balances/$addr?pagination.limit=1000" "balances_${addr}.json" || true
done

# ---- re-anchor height at end ----
fetch "/cosmos/base/tendermint/v1beta1/blocks/latest" "latest_block_end.json"
echo "done"
