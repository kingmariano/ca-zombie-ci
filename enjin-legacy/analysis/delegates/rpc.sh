#!/usr/bin/env bash
# RPC wrapper: uses BLOCKPI_RPC_URL if set, else RPC_URL. Sources ../../../.env at runtime.
# Never echoes the URL.
set -euo pipefail
set -a; source /home/heisenberg/CA/.env; set +a
URL="${BLOCKPI_RPC_URL:-$RPC_URL}"
exec cast "$@" --rpc-url "$URL"
