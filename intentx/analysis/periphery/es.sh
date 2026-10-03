#!/usr/bin/env bash
# Read-only Etherscan V2 helper. Saves raw JSON to $OUTDIR, prints summary to stdout.
# Usage: es.sh <chainid> <module> <action> <address> [extra args...]
set -euo pipefail
set -a; source /home/heisenberg/CA/.env; set +a
CID="$1"; MOD="$2"; ACT="$3"; ADDR="$4"; shift 4
: "${ETHERSCANV2_API_KEY:?missing key}"
OUTDIR="${OUTDIR:-/home/heisenberg/CA/intentx/analysis/periphery/raw}"
mkdir -p "$OUTDIR"
URL="https://api.etherscan.io/v2/api?chainid=${CID}&module=${MOD}&action=${ACT}&address=${ADDR}&apikey=${ETHERSCANV2_API_KEY}"
for kv in "$@"; do URL="${URL}&${kv}"; done
OUT="${OUTDIR}/chain${CID}_${MOD}_${ACT}_${ADDR}.json"
curl -sS --max-time 60 "$URL" -o "$OUT"
jq -c '{status,message,result_type:(.result|type),n:(.result|if type=="array" then length else 1 end)}' "$OUT" 2>/dev/null || head -c 400 "$OUT"
echo "saved: $OUT"
