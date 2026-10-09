#!/usr/bin/env bash
# C2-31 Nolus (pirin-1) — CI verification job (read-only, keyless public endpoints).
# Re-fetches live chain state + market data, then re-runs the capture model.
# Outputs: ci-out/raw/*.json (evidence), ci-out/capture_model.json, ci-out/asset_inventory.json,
#          ci-out/model_stdout.txt. No secrets are read or written.
set -uo pipefail
mkdir -p ci-out/raw

LCD="https://lcd.nolus.network"
RPC="https://rpc.nolus.network"

fetch() { # fetch <url> <outfile>
  if curl -sf --max-time 45 -H 'User-Agent: zombie-research/1.0' "$1" -o "$2"; then
    echo "OK   $2"
  else
    echo "WARN fetch failed: $1"
  fi
}

echo "== chain facts =="
fetch "$LCD/cosmos/base/tendermint/v1beta1/node_info" ci-out/raw/node_info.json
fetch "$LCD/cosmos/base/tendermint/v1beta1/blocks/latest" ci-out/raw/latest_block.json
fetch "$LCD/cosmos/staking/v1beta1/pool" ci-out/raw/staking_pool.json
fetch "$LCD/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200" ci-out/raw/validators.json
fetch "$LCD/cosmos/distribution/v1beta1/community_pool" ci-out/raw/community_pool.json
fetch "$LCD/cosmos/bank/v1beta1/supply?pagination.limit=500" ci-out/raw/supply.json

echo "== gov =="
# gov params via ABCI (the public LCD does not serve the gov params route)
curl -s --max-time 30 -H 'User-Agent: zombie-research/1.0' \
  "$RPC/abci_query?path=%22%2Fcosmos.gov.v1.Query%2FParams%22" -o ci-out/raw/gov_params_abci.json || echo "WARN gov params abci"
fetch "$LCD/cosmos/gov/v1/proposals?pagination.limit=100&pagination.reverse=true" ci-out/raw/gov_props.json
fetch "$LCD/cosmos/gov/v1/proposals/295" ci-out/raw/prop_295.json

echo "== protocol contracts =="
python3 ci/fetch_contracts.py ci-out/raw || echo "WARN contracts fetch"

echo "== market data =="
fetch "https://api.mexc.com/api/v3/depth?symbol=NLSUSDT&limit=1000" ci-out/raw/mexc_depth.json
fetch "https://api.coingecko.com/api/v3/coins/nolus?localization=false&tickers=true&market_data=true&community_data=false&developer_data=false&sparkline=false" ci-out/raw/coingecko_nolus.json

echo "== model =="
python3 analysis/model.py ci-out/raw ci-out | tee ci-out/model_stdout.txt

echo "== done =="
ls -la ci-out/ | head -20
