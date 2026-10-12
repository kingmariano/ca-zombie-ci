#!/usr/bin/env bash
# Custom CI job for the DeFi Franc deep-dive: dump live state via a public RPC.
# Read-only. Writes results to ci-out/ (uploaded as an artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

RPC="${FORK_RPC_URL:-https://ethereum-rpc.publicnode.com}"

echo "[ci] eth_blockNumber probe"
curl -s -m 15 -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$RPC" \
  | python3 -c "import sys,json; print('[ci] latest block', int(json.load(sys.stdin)['result'],16))" || true

echo "[ci] state dump"
DF_RPC="$RPC" python3 analysis/state_dump.py > ci-out/state.json 2> ci-out/state.err || echo "[ci] state dump failed (see state.err)"
wc -c ci-out/state.json || true
head -c 400 ci-out/state.json || true

echo "[ci] done"
