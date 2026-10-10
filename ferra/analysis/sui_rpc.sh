#!/usr/bin/env bash
# Sui JSON-RPC helper — public endpoints only (no keys). Usage: sui_rpc.sh <method> '<json-params>'
set -uo pipefail
METHOD="$1"; PARAMS="${2:-[]}"
ENDPOINTS=(
  "https://sui-rpc.publicnode.com"
  "https://sui-mainnet-endpoint.blockvision.org"
  "https://mainnet.suiet.app"
  "https://sui-mainnet.nodeinfra.com"
)
BODY="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$METHOD\",\"params\":$PARAMS}"
for u in "${ENDPOINTS[@]}"; do
  R=$(curl -s -m 25 -X POST -H 'Content-Type: application/json' -d "$BODY" "$u")
  if [ -n "$R" ] && ! echo "$R" | grep -q '"error"' ; then echo "$R"; exit 0; fi
  LAST="$R"
done
echo "${LAST:-NO_RESPONSE}" >&2; exit 1
