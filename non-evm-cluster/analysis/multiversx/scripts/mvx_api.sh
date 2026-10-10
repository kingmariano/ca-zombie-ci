#!/usr/bin/env bash
# Keyless read-only helper for MultiversX public API (https://api.multiversx.com)
# Usage: mvx_api.sh <path-with-query> [outfile]
# Example: mvx_api.sh "/accounts/erd1.../tokens" out.json
set -euo pipefail
BASE="https://api.multiversx.com"
P="$1"
OUT="${2:-}"
URL="${BASE}${P}"
if [ -z "$OUT" ]; then
  curl -s --max-time 60 -H "Accept: application/json" "$URL"
else
  curl -s --max-time 60 -H "Accept: application/json" "$URL" -o "$OUT"
  echo "wrote $OUT ($(wc -c < "$OUT") bytes) from $URL"
fi
