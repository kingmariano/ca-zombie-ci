#!/usr/bin/env bash
# Read-only: fetch wUSDB Transfer logs (all) + recent Redeem events for SYs + USDB activity.
set -u
ENVF=/home/heisenberg/CA/.env
export ETHERSCANV2_API_KEY="$(grep -E '^ETHERSCANV2_API_KEY=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
OUT=/home/heisenberg/CA/splice-finance/analysis/logs
mkdir -p "$OUT"
V=0x4BeD2A922654cAcC2Be974689619768FaBF24855
TRANSFER=0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
# wUSDB transfers, page 1..5
for p in 1 2 3 4 5; do
  curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
    --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
    --data-urlencode "fromBlock=0" --data-urlencode "toBlock=latest" --data-urlencode "address=$V" \
    --data-urlencode "topic0=$TRANSFER" --data-urlencode "page=$p" --data-urlencode "offset=1000" \
    --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/wusdb_transfer_p$p.json"
  n=$(python3 -c "import json;r=json.load(open('$OUT/wusdb_transfer_p$p.json')).get('result');print(len(r) if isinstance(r,list) else 'ERR')")
  echo "wusdb transfers page $p -> $n"
  [ "$n" = "ERR" ] && break
  [ "$n" -lt 1000 ] && break
  sleep 0.3
done
# Redeem events on SY hUSDB (topic0 of Redeem(address,address,address,uint256,uint256))
RD=0xaee47cdf925cf525fdae94f9777ee5a06cac37e1c41220d0a8a89ed154f62d1c
for pair in "husdbsy:0x13293dacab830d8fa2e0e961fb997b3f37186f46" "wusdbsy:0xf904fa59d1eacec21d758ccd2fe43261a1dd5470"; do
  name="${pair%%:*}"; a="${pair##*:}"
  curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
    --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
    --data-urlencode "fromBlock=34000000" --data-urlencode "toBlock=latest" --data-urlencode "address=$a" \
    --data-urlencode "topic0=$RD" --data-urlencode "page=1" --data-urlencode "offset=100" \
    --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/${name}_redeem_recent.json"
  n=$(python3 -c "import json;r=json.load(open('$OUT/${name}_redeem_recent.json')).get('result');print(len(r) if isinstance(r,list) else 'ERR')")
  echo "$name recent redeems -> $n"
  sleep 0.3
done
