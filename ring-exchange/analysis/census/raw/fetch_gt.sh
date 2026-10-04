#!/bin/bash
# Fetch GeckoTerminal data for all fw tokens on HyperEVM. Read-only.
cd "$(dirname "$0")"
UA="research/1.0 (read-only census)"
GT="https://api.geckoterminal.com/api/v2"

declare -A TOK
TOK[fwWHYPE]="0x9e1148bC3665a9f7C35F313d89c0432c34928AEf"
TOK[fwUETH]="0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397"
TOK[fwUSDC]="0xd2646b9B02859416D8cBc759F85f0676f6E19974"
TOK[fwUSDT0]="0x7576dd9a2775bFd789616d9eA7A2af21d06782D0"
TOK[fwUSDH]="0x09D21E89EF332347eb3E1E496f1265a600e364C1"

for name in fwWHYPE fwUETH fwUSDC fwUSDT0 fwUSDH; do
  addr=${TOK[$name]}
  curl -s -A "$UA" "$GT/networks/hyperevm/tokens/$addr/pools?page=1" -o "gt_${name}_pools_p1.json"
  sleep 2.2
  curl -s -A "$UA" "$GT/networks/hyperevm/tokens/$addr/pools?page=2" -o "gt_${name}_pools_p2.json"
  sleep 2.2
  curl -s -A "$UA" "$GT/networks/hyperevm/tokens/$addr/info" -o "gt_${name}_info.json"
  sleep 2.2
done

# search endpoint for addr
for name in fwWHYPE fwUETH fwUSDC fwUSDT0 fwUSDH; do
  addr=${TOK[$name]}
  curl -s -A "$UA" "$GT/search/pools?query=$addr&network=hyperevm" -o "gt_search_${name}.json"
  sleep 2.2
done

# known pairs
declare -A PAIR
PAIR[p1_fwUETH_fwWHYPE]="0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a"
PAIR[p2_fwUSDH_fwUSDC]="0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3"
PAIR[p3_fwUSDH_fwUSDT0]="0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150"
PAIR[p4_fwUSDT0_fwUSDC]="0x8868a630dD13A954D3f8B186508EF6c733BE959F"
PAIR[p5_fwUSDT0_fwWHYPE]="0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17"
for name in p1_fwUETH_fwWHYPE p2_fwUSDH_fwUSDC p3_fwUSDH_fwUSDT0 p4_fwUSDT0_fwUSDC p5_fwUSDT0_fwWHYPE; do
  addr=${PAIR[$name]}
  curl -s -A "$UA" "$GT/networks/hyperevm/pools/$addr" -o "gt_pool_${name}.json"
  sleep 2.2
done

# dexes list + search for 'fw' and 'ring'
curl -s -A "$UA" "$GT/networks/hyperevm/dexes" -o gt_hyperevm_dexes.json
sleep 2.2
curl -s -A "$UA" "$GT/search/pools?query=fwWHYPE&network=hyperevm" -o gt_search_name_fwWHYPE.json
sleep 2.2
curl -s -A "$UA" "$GT/search/pools?query=ring&network=hyperevm" -o gt_search_name_ring.json
sleep 2.2
curl -s -A "$UA" "$GT/networks/hyperevm/tokens/multi/${TOK[fwWHYPE]},${TOK[fwUETH]},${TOK[fwUSDC]},${TOK[fwUSDT0]},${TOK[fwUSDH]}" -o gt_tokens_multi.json

echo done
ls -la gt_*.json | head -50
