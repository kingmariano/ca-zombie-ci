#!/usr/bin/env bash
# Fetch ALL DelegatesChanged events for Enjin legacy templates via Etherscan V2.
# Key is read from ../.env at runtime; never stored here.
set -euo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env; set +a

NFT=0x13fa4b9a6c2f2604c919f96f456e3b50e968b157
FT=0x268c039a3127d3107c014f0dc6c390a53e6db27f
TOPIC0=0x3234040ce3bd4564874e44810f198910133a1b24c4e84aac87edbf6b458f5353

fetch_all() {
  local label="$1" addr="$2"
  local page=1
  while :; do
    local out="raw/${label}_page_${page}.json"
    if [ ! -s "$out" ]; then
      curl -s --max-time 60 \
        "https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=${addr}&topic0=${TOPIC0}&page=${page}&offset=1000&apikey=${ETHERSCANV2_API_KEY}" \
        -o "$out"
      sleep 0.3
    fi
    local status n
    status=$(python3 -c "import json;d=json.load(open('$out'));print(d.get('status'),d.get('message'))" 2>/dev/null || echo "PARSE_ERR")
    n=$(python3 -c "import json;d=json.load(open('$out'));print(len(d.get('result',[])) if isinstance(d.get('result'),list) else 0)" 2>/dev/null || echo 0)
    echo "${label} page ${page}: status=${status} n=${n}"
    if [ "$n" -lt 1000 ]; then break; fi
    page=$((page+1))
    if [ "$page" -gt 20 ]; then echo "ABORT: >20 pages"; exit 1; fi
  done
}

fetch_all nft "$NFT"
fetch_all ft "$FT"
echo DONE
