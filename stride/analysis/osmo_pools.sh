#!/usr/bin/env bash
set -uo pipefail
B="https://lcd.osmosis.zone"
KEY=""
PAGE=0
: > raw/osmo_strd_pools.jsonl
while :; do
  URL="$B/osmosis/gamm/v1beta1/pools?pagination.limit=1000"
  [ -n "$KEY" ] && URL="$URL&pagination.key=$KEY"
  curl -s -m 30 "$URL" -o /tmp/opencode/op.json || break
  PAGE=$((PAGE+1))
  jq -c --arg d "ibc/A8CA5EE328FA10C9519DF6057DA1F69682D28F7D0F5CCC7ECB72E3DCA2D157A4" '.pools[] | select([.poolAssets[].token.denom] | index($d))' /tmp/opencode/op.json >> raw/osmo_strd_pools.jsonl 2>/dev/null
  KEY=$(jq -r '.pagination.next_key // empty' /tmp/opencode/op.json 2>/dev/null)
  echo "page $PAGE next_key=${KEY:0:12} strd_so_far=$(wc -l < raw/osmo_strd_pools.jsonl)"
  [ -z "$KEY" ] && break
  [ "$PAGE" -gt 8 ] && break
done
