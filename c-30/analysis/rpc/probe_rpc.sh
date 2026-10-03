#!/usr/bin/env bash
# C-30 BounceBit chain liveness probe (read-only, no transactions)
# Usage: bash probe_rpc.sh
set -u
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
OUT="$(dirname "$0")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

probe() {
  local name="$1" url="$2" method="$3" params="${4:-[]}"
  curl -sS -m 25 -A "$UA" -H 'Content-Type: application/json' \
    -X POST "$url" --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":$params}" 2>&1
}

RPC="https://fullnode-mainnet.bouncebitapi.com"
RPC2="https://6001.rpc.thirdweb.com"

echo "[$TS] === BounceBit chain probe ==="
echo "--- official RPC chainId ---"
probe official "$RPC" eth_chainId | tee "$OUT/chainid_official.json"; echo
echo "--- official RPC blockNumber #1 ---"
probe official "$RPC" eth_blockNumber | tee "$OUT/blocknumber_official_1.json"; echo
echo "--- official RPC syncing ---"
probe official "$RPC" eth_syncing | tee "$OUT/syncing_official.json"; echo
echo "--- official RPC latest block header ---"
probe official "$RPC" eth_getBlockByNumber '["latest",false]' | tee "$OUT/latest_block_official.json"; echo
sleep 20
echo "--- official RPC blockNumber #2 (after 20s) ---"
probe official "$RPC" eth_blockNumber | tee "$OUT/blocknumber_official_2.json"; echo
echo "--- thirdweb RPC chainId ---"
probe thirdweb "$RPC2" eth_chainId | tee "$OUT/chainid_thirdweb.json"; echo
echo "--- thirdweb RPC blockNumber ---"
probe thirdweb "$RPC2" eth_blockNumber | tee "$OUT/blocknumber_thirdweb.json"; echo
echo "--- thirdweb RPC latest block header ---"
probe thirdweb "$RPC2" eth_getBlockByNumber '["latest",false]' | tee "$OUT/latest_block_thirdweb.json"; echo
echo "[done]"
