#!/bin/bash
# Enumerate all objects of a given type with pagination (first:50).
# Usage: ./enum_type.sh <full_type_without_generic> <outfile.jsonl>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GQL="$HERE/gql.sh"
TYPE="$1"
OUT="$2"
cursor="null"
page=0
: > "$OUT"
while :; do
  body=$(jq -cn --arg t "$TYPE" --argjson c "$cursor" \
    '{query: "query($t:String!,$c:String){ objects(first: 50, after: $c, filter: {type: $t}) { pageInfo { hasNextPage endCursor } nodes { address version asMoveObject { contents { type { repr } json } } } } }", variables: {t: $t, c: $c}}')
  resp=$(echo "$body" | "$GQL")
  if [ -z "$resp" ]; then echo "EMPTY RESPONSE page=$page" >&2; exit 1; fi
  echo "$resp" >> "$OUT"
  n=$(echo "$resp" | jq '.data.objects.nodes | length' 2>/dev/null)
  if [ -z "$n" ] || [ "$n" = "null" ]; then echo "BAD RESPONSE page=$page: $(echo "$resp" | head -c 300)" >&2; exit 1; fi
  hasNext=$(echo "$resp" | jq -r '.data.objects.pageInfo.hasNextPage')
  cursor=$(echo "$resp" | jq -c '.data.objects.pageInfo.endCursor')
  echo "page=$page nodes=$n hasNext=$hasNext" >&2
  page=$((page+1))
  if [ "$hasNext" != "true" ]; then break; fi
  sleep 0.4
done
echo "done: $OUT pages=$page" >&2
