#!/usr/bin/env bash
# cwq.sh — read-only CosmWasm smart query against public Injective LCD.
# Usage: ./cwq.sh <contract> '<json-query>'
# Uses only keyless public endpoints. Never add keyed URLs here.
set -euo pipefail
LCD="${LCD:-https://injective-api.polkachu.com}"
C="$1"; Q="$2"
B64=$(printf '%s' "$Q" | base64 -w0)
curl -s --max-time 30 "$LCD/cosmwasm/wasm/v1/contract/$C/smart/$B64" \
  -H "User-Agent: Mozilla/5.0" | jq -c '.data // .'
