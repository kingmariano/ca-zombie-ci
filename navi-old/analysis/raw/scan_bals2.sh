#!/bin/bash
GQL=https://graphql.mainnet.sui.io/graphql
cursor=""
> legacy_bals_all.jsonl
for i in $(seq 1 12); do
  if [ -z "$cursor" ]; then
    q='{ objects(first: 50, filter: {type: "0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive::IncentiveBal"}) { pageInfo { hasNextPage endCursor } nodes { address version asMoveObject { contents { type { repr } json } } } } }'
  else
    q="{ objects(first: 50, after: \"$cursor\", filter: {type: \"0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive::IncentiveBal\"}) { pageInfo { hasNextPage endCursor } nodes { address version asMoveObject { contents { type { repr } json } } } } }"
  fi
  body=$(jq -n --arg q "$q" '{query: $q}')
  resp=$(echo "$body" | curl -s -m 30 $GQL -H 'Content-Type: application/json' --data-binary @-)
  echo "$resp" | jq -c '.data.objects.nodes[]?' >> legacy_bals_all.jsonl
  hasnext=$(echo "$resp" | jq -r '.data.objects.pageInfo.hasNextPage')
  cursor=$(echo "$resp" | jq -r '.data.objects.pageInfo.endCursor')
  [ "$hasnext" = "true" ] || break
  sleep 0.3
done
echo "total objects: $(wc -l < legacy_bals_all.jsonl)"
echo "non-zero balances:"
jq -r 'select((.asMoveObject.contents.json.balance // "0") != "0") | "\(.address) \(.asMoveObject.contents.type.repr) bal=\(.asMoveObject.contents.json.balance)"' legacy_bals_all.jsonl
