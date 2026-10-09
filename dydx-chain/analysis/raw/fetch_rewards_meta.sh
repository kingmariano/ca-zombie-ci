#!/usr/bin/env bash
# Read-only: validator outstanding rewards + denom metadata + market data.
set -uo pipefail
OUT=/home/heisenberg/CA/dydx-chain/analysis/raw
BASES=(https://dydx-dao-api.polkachu.com https://dydx-rest.publicnode.com)
get() { # url outfile
  local url="$1" f="$2"
  curl -sS --max-time 25 "$url" -o "$OUT/$f" && jq -e . "$OUT/$f" >/dev/null 2>&1 && echo "OK $f" || echo "FAIL $f"
}
GETB() { # path outfile
  local p="$1" f="$2" base
  for base in "${BASES[@]}"; do
    if curl -sS --max-time 20 "$base$p" -o "$OUT/$f" && jq -e . "$OUT/$f" >/dev/null 2>&1; then echo "OK $f ($base)"; return; fi
  done
  echo "FAIL $f"
}

mkdir -p "$OUT/rewards"
i=0
for v in $(jq -r '.validators[].operator_address' "$OUT/validators_bonded.json"); do
  i=$((i+1))
  n=$(printf "%02d" "$i")
  GETB "/cosmos/distribution/v1beta1/validators/$v/outstanding_rewards" "rewards/rewards_$n.json"
done
echo "validators: $i"

# denom metadata for IBC denoms on dydx
for h in 8E27BA2D5493AF5636760E354E46004562C46AB7EC0CC4C1CA14E9E20E2545B5 15781DDDCD499274C978F31A0DBD6DA93D8EE0F7200891898549AFC7C5B5948A AD9B9B572C8099DF19DC6233FAC79C0AFD20972864F258439C2A96ED7FC1B903 E5DA7F807E9588AA76C33C1E0A91B5D34076F7D6FA170297DFD076EB14D36C0A; do
  curl -sS --max-time 20 "https://dydx-dao-api.polkachu.com/cosmos/bank/v1beta1/denoms_metadata/ibc%2F$h" -o "$OUT/denom_metadata_$h.json" 2>/dev/null || true
  echo "meta $h: $(head -c 200 "$OUT/denom_metadata_$h.json")"
done

# fresh distribution account balance + community pool for tight reconciliation
GETB "/cosmos/bank/v1beta1/balances/dydx1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8wx2cfg?pagination.limit=1000" "balances_dist_recon.json"
GETB "/cosmos/distribution/v1beta1/community_pool" "community_pool_recon.json"
GETB "/cosmos/base/tendermint/v1beta1/blocks/latest" "latest_block_recon.json"

# stride denom metadata (stadydx decimals)
for u in "https://stride-rest.publicnode.com" "https://stride-api.polkachu.com" "https://rest.cosmos.directory/stride"; do
  if curl -sS --max-time 15 "$u/cosmos/bank/v1beta1/denoms_metadata/stadydx" -o "$OUT/stride_metadata_stadydx.json" 2>/dev/null && jq -e . "$OUT/stride_metadata_stadydx.json" >/dev/null 2>&1; then echo "OK stride meta via $u"; break; fi
done
head -c 400 "$OUT/stride_metadata_stadydx.json" 2>/dev/null; echo

# market data
get "https://coins.llama.fi/prices/current/coingecko:dydx" "price_llama_dydx.json"
get "https://coins.llama.fi/prices/current/coingecko:stride-staked-dydx" "price_llama_stdydx.json"
get "https://coins.llama.fi/prices/current/coingecko:usd-coin" "price_llama_usdc.json"
get "https://api.coingecko.com/api/v3/simple/price?ids=dydx&vs_currencies=usd&include_24hr_vol=true&include_market_cap=true&include_last_updated_at=true" "price_cg_simple_dydx.json"
get "https://api.coingecko.com/api/v3/coins/dydx?localization=false&tickers=false&community_data=false&developer_data=false" "cg_coin_dydx.json"
get "https://indexer.dydx.trade/v4/perpetualMarkets" "indexer_perpetual_markets.json"
echo done
