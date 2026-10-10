#!/usr/bin/env bash
# Read-only fetch of full runtime bytecode for every allow-listed address.
# Keyless public RPC only. Writes raw/code_<addr>.hex and raw/codes.jsonl
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RPC="https://api.zilliqa.com"
BLOCK=$(curl -s -m 30 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$RPC" | python3 -c 'import sys,json;print(int(json.load(sys.stdin)["result"],16))')
echo "head block: $BLOCK"
: > "$HERE/raw/codes.jsonl"
while read -r addr; do
  [ -z "$addr" ] && continue
  resp=$(curl -s -m 30 -X POST -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$addr\",\"latest\"],\"id\":1}" "$RPC")
  code=$(echo "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("result","0x"))')
  printf '%s' "$code" > "$HERE/raw/code_${addr}.hex"
  echo "{\"address\":\"$addr\",\"block\":$BLOCK,\"size\":$(( (${#code} - 2) / 2 ))}" >> "$HERE/raw/codes_meta.jsonl"
  sleep 0.12
done < "$HERE/allowlist.txt"
echo "fetched $(wc -l < "$HERE/raw/codes_meta.jsonl") codes"
