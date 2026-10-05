#!/usr/bin/env bash
# C2-05 — Stride governance capture: reproducible live-state evidence pull + cost model.
# Read-only: public LCD / gRPC / DEX quote APIs only. No transactions. No secrets.
# Runs from the finding folder root (stride/). Writes ci-out/raw/* and ci-out/report.{json,txt}
set -uo pipefail
OUT=ci-out
RAW=$OUT/raw
mkdir -p "$RAW"

REST="https://rest.cosmos.directory/stride"
REST2="https://stride-api.polkachu.com"
HUB="https://rest.cosmos.directory/cosmoshub"
CEL="https://rest.cosmos.directory/celestia"
SQS="https://sqs.osmosis.zone/router/quote"
STRD="ibc/A8CA5EE328FA10C9519DF6057DA1F69682D28F7D0F5CCC7ECB72E3DCA2D157A4"
USDC="ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4"

get() { # $1 name, $2 url ; tries REST then REST2, retries each twice
  code=000
  for url in "$2" "${3:-}"; do
    [ -z "$url" ] && continue
    for try in 1 2; do
      code=$(curl -s -m 30 -o "$RAW/$1.json" -w "%{http_code}" "$url" || true)
      [ "$code" = "200" ] && break
      sleep 2
    done
    [ "$code" = "200" ] && break
  done
  echo "pull $1 http=$code"
}

echo "=== C2-05 Stride pull: $(date -u +%FT%TZ) ==="
get height "$REST/cosmos/base/tendermint/v1beta1/blocks/latest" "$REST2/cosmos/base/tendermint/v1beta1/blocks/latest"
get staking_pool "$REST/cosmos/staking/v1beta1/pool" "$REST2/cosmos/staking/v1beta1/pool"
get staking_params "$REST/cosmos/staking/v1beta1/params" "$REST2/cosmos/staking/v1beta1/params"
get community_pool "$REST/cosmos/distribution/v1beta1/community_pool" "$REST2/cosmos/distribution/v1beta1/community_pool"
get validators "$REST/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200" "$REST2/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200"
for d in ustrd stuatom stutia; do
  get "supply_$d" "$REST/cosmos/bank/v1beta1/supply/by_denom?denom=$d" "$REST2/cosmos/bank/v1beta1/supply/by_denom?denom=$d"
done
for id in 282 283 284 285; do
  get "prop_$id" "$REST/cosmos/gov/v1/proposals/$id" "$REST2/cosmos/gov/v1/proposals/$id"
  get "tally_$id" "$REST/cosmos/gov/v1/proposals/$id/tally" "$REST2/cosmos/gov/v1/proposals/$id/tally"
done

# --- gRPC (gov params + host zones + mint). Install grpcurl if missing.
export PATH="$PATH:$HOME/go/bin:/usr/local/bin:$PWD/$RAW"
if ! command -v grpcurl >/dev/null 2>&1; then
  echo "installing grpcurl..."
  curl -sL -o /tmp/grpcurl.tgz "https://github.com/fullstorydev/grpcurl/releases/download/v1.9.3/grpcurl_1.9.3_linux_x86_64.tar.gz" || true
  tar -xzf /tmp/grpcurl.tgz -C "$RAW" grpcurl 2>/dev/null || true
  tar -xzf /tmp/grpcurl.tgz -C /usr/local/bin grpcurl 2>/dev/null || true
  chmod +x "$RAW/grpcurl" 2>/dev/null || true
  export PATH="$PATH:$PWD/$RAW"
fi
GRPC="stride.lavenderfive.com:443"
GRPC2="grpc.stride.citizenweb3.com:443"
grpc_pull() { # $1 outname, $2 method
  for G in "$GRPC" "$GRPC2"; do
    if grpcurl -max-time 60 -d '{}' "$G" "$2" > "$RAW/$1.json" 2>"$RAW/$1.err"; then
      if [ -s "$RAW/$1.json" ] && ! grep -q '"code"' "$RAW/$1.json"; then echo "grpc $1 via $G ok"; return 0; fi
    fi
  done
  echo "grpc $1 FAILED"
}
grpc_pull gov_params_grpc cosmos.gov.v1.Query/Params
grpc_pull hostzones_grpc stride.stakeibc.Query/HostZoneAll
grpc_pull mint_params stride.mint.v1beta1.Query/Params

# --- host-chain ICA custody (verified on-chain)
curl -s -m 30 "$HUB/cosmos/staking/v1beta1/delegations/cosmos10uxaa5gkxpeungu2c9qswx035v6t3r24w6v2r6dxd858rq2mzknqj8ru28?pagination.limit=200" -o "$RAW/hub_ica_delegations_full.json" -w "hub_deleg http=%{http_code}\n"
curl -s -m 30 "$HUB/cosmos/bank/v1beta1/balances/cosmos10uxaa5gkxpeungu2c9qswx035v6t3r24w6v2r6dxd858rq2mzknqj8ru28" -o "$RAW/hub_ica_balance.json"
curl -s -m 30 "$CEL/cosmos/staking/v1beta1/delegations/celestia1rdfn69mf3xey2jlqyp70vljtx6df4lkydndplz9drdueuhqh8geqk9gjkj?pagination.limit=200" -o "$RAW/cel_ica_delegations_full.json" -w "cel_deleg http=%{http_code}\n"
curl -s -m 30 "$CEL/cosmos/bank/v1beta1/balances/celestia1rdfn69mf3xey2jlqyp70vljtx6df4lkydndplz9drdueuhqh8geqk9gjkj" -o "$RAW/cel_ica_balance.json"
curl -s -m 30 "$HUB/ibc/apps/interchain_accounts/host/v1/params" -o "$RAW/hub_ica_params.json" -w "hub_ica_params http=%{http_code}\n"
curl -s -m 30 "$CEL/ibc/apps/interchain_accounts/host/v1/params" -o "$RAW/cel_ica_params.json" -w "cel_ica_params http=%{http_code}\n"

# --- Osmosis STRD market: buy/sell curves via SQS router
: > "$RAW/sqs_quotes.jsonl"
q() { # $1 side, $2 tokenIn
  resp=$(curl -s -m 40 "$SQS?tokenIn=$2&tokenOutDenom=$3")
  jq -cn --arg side "$1" --arg in "$2" --argjson resp "${resp:-{\}}" '{side:$side,in:$in,resp:$resp}' >> "$RAW/sqs_quotes.jsonl" 2>/dev/null \
    || echo "{\"side\":\"$1\",\"in\":\"$2\",\"resp\":{}}" >> "$RAW/sqs_quotes.jsonl"
}
for amt in 1000000 1000000000 10000000000 50000000000 100000000000 200000000000 434000000000 1000000000000 2000000000000 5000000000000; do
  q buy_osmo "${amt}uosmo" "$STRD"
done
for amt in 1000000000 10000000000 100000000000 500000000000 1000000000000 2210000000000 3320000000000; do
  q sell_osmo "${amt}${STRD}" "uosmo"
done
for amt in 1000000000 5000000000 10000000000 15800000000 30000000000; do
  q buy_usdc "${amt}${USDC}" "$STRD"
done

# --- prices (DefiLlama batch)
curl -s -m 40 "https://coins.llama.fi/prices/current/coingecko:stride,coingecko:cosmos,coingecko:celestia,coingecko:stride-staked-atom,coingecko:stride-staked-tia,coingecko:osmosis,coingecko:juno-network,coingecko:stargaze,coingecko:sommelier,coingecko:evmos,coingecko:terra-luna-2,coingecko:injective-protocol,coingecko:band-protocol,coingecko:umee,coingecko:comdex,coingecko:dydx-chain,coingecko:dymension,coingecko:saga-2,coingecko:islamic-coin" -o "$RAW/prices.json" -w "prices http=%{http_code}\n"

# --- compute
python3 ci/analyze.py | tee "$OUT/report.txt"
echo "=== done $(date -u +%FT%TZ) ==="
