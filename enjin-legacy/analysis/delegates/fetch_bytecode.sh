#!/usr/bin/env bash
# Pull runtime bytecode for a list of addresses into code/<addr>.hex (no RPC URL stored).
set -euo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env; set +a
URL="${BLOCKPI_RPC_URL:-$RPC_URL}"
for a in "$@"; do
  out="code/${a}.hex"
  if [ ! -s "$out" ]; then
    cast code "$a" --rpc-url "$URL" > "$out"
  fi
  printf '%s bytes: %s\n' "$a" "$(( ($(wc -c < "$out") - 1) / 2 ))"
done
