#!/usr/bin/env bash
# Fetch verified source for addresses on Fraxtal (chainid 252) via Etherscan V2.
# Usage: bash fetch_src.sh <addr> [<addr> ...]
# Requires ETHERSCANV2_API_KEY in env (sourced from .env by caller). Never prints the key.
set -uo pipefail
mkdir -p /home/heisenberg/CA/ra-exchange/analysis/src
for a in "$@"; do
  out="/home/heisenberg/CA/ra-exchange/analysis/src/${a}.json"
  curl -s "https://api.etherscan.io/v2/api?chainid=252&module=contract&action=getsourcecode&address=${a}&apikey=${ETHERSCANV2_API_KEY}" -o "$out"
  status=$(python3 -c "import json;d=json.load(open('$out'));print(d.get('status'),d.get('message'))" 2>/dev/null)
  name=$(python3 -c "import json;d=json.load(open('$out'));r=d.get('result');print(r[0].get('ContractName') if isinstance(r,list) and r else 'NONE')" 2>/dev/null)
  echo "$a -> status=$status name=$name bytes=$(wc -c < $out)"
done
