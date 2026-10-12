#!/usr/bin/env bash
# Multi-RPC helper: picks the first RPC that supports eth_call.
# NEVER prints the RPC URL itself. Keys stay in env.
set -u
cd /home/heisenberg/CA
set -a; source .env 2>/dev/null; set +a

CANDIDATES=(
  "${RPC_URL:-}"
  "${NODEREAL_ETH_RPC_URL:-}"
  "${BLOCKPI_RPC_URL:-}"
  "https://ethereum-rpc.publicnode.com"
  "https://eth.drpc.org"
  "https://1rpc.io/eth"
  "https://rpc.ankr.com/eth"
)

pick_rpc() {
  for r in "${CANDIDATES[@]}"; do
    [ -z "$r" ] && continue
    out=$(cast call 0x0000000000000000000000000000000000000000 "totalSupply()(uint256)" --rpc-url "$r" 2>/dev/null) || true
    if [ -n "${out:-}" ]; then echo "$r"; return 0; fi
    # eth_call to nonexistent fn on EOA returns 0x -> cast errors; try block-number+code instead
    code=$(cast code 0xae7ab96520de3a18e5e111b5eaab095312d7fe84 --rpc-url "$r" 2>/dev/null | head -c 4) || true
    if [ "${code:-}" = "0x60" ] || [ "${code:-}" = "0x36" ] || [ "${code:-}" = "0x60" ]; then echo "$r"; return 0; fi
    # fallback: try a known good call (stETH totalSupply)
    ts=$(cast call 0xae7ab96520de3a18e5e111b5eaab095312d7fe84 "totalSupply()(uint256)" --rpc-url "$r" 2>/dev/null) || true
    if [ -n "${ts:-}" ]; then echo "$r"; return 0; fi
  done
  return 1
}

RPC=$(pick_rpc) || { echo "NO WORKING RPC" >&2; exit 1; }
echo "RPC_OK host=$(echo "$RPC" | sed -E 's#(https?://[^/]+).*#\1#')" >&2
export RPC
