#!/bin/bash
TID=0xca34cdeaa71e7094e7d23116a50bf671804da8b54854f33ec7b2b1b9ca69087e
TOKEN=""
: > lineageB_pools_raw.jsonl
for i in $(seq 1 10); do
  if [ -z "$TOKEN" ]; then
    req="{\"parent\":\"$TID\",\"page_size\":50,\"read_mask\":{\"paths\":[\"name\",\"value\"]}}"
  else
    req="{\"parent\":\"$TID\",\"page_size\":50,\"page_token\":\"$TOKEN\",\"read_mask\":{\"paths\":[\"name\",\"value\"]}}"
  fi
  resp=$(timeout 60 grpcurl -max-time 50 -d "$req" fullnode.mainnet.sui.io:443 sui.rpc.v2.StateService/ListDynamicFields 2>/dev/null)
  echo "$resp" | jq -c '.dynamicFields[]?' >> lineageB_pools_raw.jsonl
  TOKEN=$(echo "$resp" | jq -r '.nextPageToken // empty')
  [ -z "$TOKEN" ] && break
  sleep 0.3
done
echo "fetched: $(wc -l < lineageB_pools_raw.jsonl)"
