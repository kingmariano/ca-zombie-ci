#!/usr/bin/env bash
# Fetch DelegateUpdate (topic0 0x3234040c...) history for the CryptoItems proxy 0xfaafdc07.
set -euo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env; set +a
ADDR=0xfaafdc07907ff5120a76b34b731b278c38d6043c
TOPIC0=0x3234040ce3bd4564874e44810f198910133a1b24c4e84aac87edbf6b458f5353
page=1
while :; do
  out="raw/items_page_${page}.json"
  if [ ! -s "$out" ]; then
    curl -s --max-time 60 \
      "https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=${ADDR}&topic0=${TOPIC0}&page=${page}&offset=1000&apikey=${ETHERSCANV2_API_KEY}" \
      -o "$out"
    sleep 0.3
  fi
  n=$(python3 -c "import json;d=json.load(open('$out'));print(len(d.get('result',[])) if isinstance(d.get('result'),list) else 0)" 2>/dev/null || echo 0)
  echo "items page ${page}: n=${n}"
  if [ "$n" -lt 1000 ]; then break; fi
  page=$((page+1))
done
echo DONE
