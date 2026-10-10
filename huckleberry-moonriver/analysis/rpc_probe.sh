#!/usr/bin/env bash
# Moonriver liveness probe — public endpoints only. Usage: rpc_probe.sh <tag>
TAG="${1:-probe}"
UA="Mozilla/5.0 (X11; Linux x86_64) zombie-hunt-research/1.0"
RPCs=(
  "https://rpc.api.moonriver.moonbeam.network"
  "https://moonriver.public.blastapi.io"
  "https://moonriver-rpc.publicnode.com"
  "https://moonriver.api.onfinality.io/public"
  "https://moonriver.drpc.org"
)
echo "{\"tag\":\"$TAG\",\"utc\":\"$(date -u +%FT%TZ)\",\"probes\":["
first=1
for rpc in "${RPCs[@]}"; do
  bn=$(curl -s --max-time 25 -A "$UA" -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$rpc" | head -c 400)
  blk=$(curl -s --max-time 25 -A "$UA" -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest",false]}' "$rpc" | head -c 4000)
  # extract fields with sed/jq fallback
  num=$(echo "$blk" | grep -o '"number":"[^"]*"' | head -1 | cut -d'"' -f4)
  hash=$(echo "$blk" | grep -o '"hash":"[^"]*"' | head -1 | cut -d'"' -f4)
  ts=$(echo "$blk" | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
  tsdec=$((16#${ts#0x})) 2>/dev/null || tsdec=""
  tsutc=""; [ -n "$tsdec" ] && tsutc=$(date -u -d "@$tsdec" +%FT%TZ 2>/dev/null)
  [ $first -eq 0 ] && echo ","
  first=0
  printf '{"rpc":"%s","blockNumber_raw":%s,"head_number":%s,"head_hash":"%s","head_timestamp":%s,"head_utc":"%s"}' \
    "$rpc" "${bn:-null}" "${num:-null}" "${hash:-}" "${tsdec:-null}" "${tsutc:-}"
done
echo ']}'
