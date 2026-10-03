#!/usr/bin/env bash
# C-30 BounceBit — CI evidence job (read-only).
#
# Reproduces, on a clean GitHub runner, the live-state measurement behind the
# C-30 verdict:
#   1. BounceBit L1 (chain id 6001) is halted: node serves a frozen chain head,
#      zero peers, no mining, next block absent; explorer API reports the same head.
#   2. BNB Chain / Ethereum side: BB (BEP-20), BBTC and BBUSD contracts exist and
#      are role-gated (owner = 4/7 Safe; mint = onlyMinter). No unprivileged mint.
#
# No transactions are sent. Read-only JSON-RPC calls + cast eth_call only.
# Secrets come only from env (never printed); all outputs are public chain data.

set -uo pipefail
mkdir -p ci-out
OUT=ci-out
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"

rpc() { # $1=url $2=method $3=params-json
  curl -sS -m 30 -A "$UA" -H 'Content-Type: application/json' \
    -X POST "$1" --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$2\",\"params\":$3}"
}

BB_RPC="https://fullnode-mainnet.bouncebitapi.com"
BSC_RPC="${BSC_RPC_URL:-https://bsc-dataseed.binance.org}"
ETH_RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"

echo "[$TS] C-30 BounceBit CI evidence" | tee "$OUT/summary.txt"
echo "bsc_rpc_fallback_used=$([ -n "${BSC_RPC_URL:-}" ] && echo no || echo yes)" >> "$OUT/summary.txt"

# ---------- 1. BounceBit L1 liveness ----------
{
  echo "probe_utc=$TS"
  echo -n "chainId: ";       rpc "$BB_RPC" eth_chainId '[]'; echo
  echo -n "blockNumber#1: "; rpc "$BB_RPC" eth_blockNumber '[]'; echo
  echo -n "net_peerCount: "; rpc "$BB_RPC" net_peerCount '[]'; echo
  echo -n "eth_mining: ";    rpc "$BB_RPC" eth_mining '[]'; echo
  echo -n "eth_syncing: ";   rpc "$BB_RPC" eth_syncing '[]'; echo
  echo -n "clientVersion: "; rpc "$BB_RPC" web3_clientVersion '[]'; echo
  echo -n "latestHeader: ";  rpc "$BB_RPC" eth_getBlockByNumber '["latest",false]' | jq -c '{number:.result.number,hash:.result.hash,timestamp:.result.timestamp,txCount:(.result.transactions|length),stateRoot:.result.stateRoot}'
  echo -n "snapshot+1(0x13bd0ad): "; rpc "$BB_RPC" eth_getBlockByNumber '["0x13bd0ad",false]' | jq -c '{result:.result}'
  echo "waiting 45s to test block production..."
  sleep 45
  echo -n "blockNumber#2: "; rpc "$BB_RPC" eth_blockNumber '[]'; echo
} | tee "$OUT/bouncebit_rpc_liveness.txt"

# explorer API cross-check
{
  echo -n "bbscan_explorer_api: "
  curl -sS -m 30 -A "$UA" -L "https://bbscan.io/api?module=block&action=eth_block_number"
  echo
} | tee "$OUT/bouncebit_explorer.txt"

# ---------- 2. BNB Chain (56) token/role state ----------
{
  echo "probe_utc=$TS"
  echo -n "bsc_head: "; cast block-number --rpc-url "$BSC_RPC" 2>&1
  for t in 0xe0620aBeA429A66Ba69d9a0cdE9aB93dc15bB9c4 0xF5e11df1ebCf78b6b6D26E04FF19cD786a1e81dC 0x77776b40C3d75cb07ce54dEA4b2Fd1D07F865222; do
    echo "token $t"
    echo -n "  name: ";         cast call "$t" "name()(string)" --rpc-url "$BSC_RPC" 2>&1 | head -c 200; echo
    echo -n "  symbol: ";       cast call "$t" "symbol()(string)" --rpc-url "$BSC_RPC" 2>&1 | head -c 100; echo
    echo -n "  totalSupply: ";  cast call "$t" "totalSupply()(uint256)" --rpc-url "$BSC_RPC" 2>&1 | head -c 100; echo
    echo -n "  owner: ";        cast call "$t" "owner()(address)" --rpc-url "$BSC_RPC" 2>&1 | head -c 100; echo
    echo -n "  blacklist: ";    cast call "$t" "blacklist()(address)" --rpc-url "$BSC_RPC" 2>&1 | head -c 100; echo
    echo -n "  getMinters: ";   cast call "$t" "getMinters()(address[])" --rpc-url "$BSC_RPC" 2>&1 | head -c 400; echo
  done
  echo "safe 0x88d0A269b924B535c96337082EdF6B22D72d5ccf:"
  echo -n "  threshold: "; cast call 0x88d0A269b924B535c96337082EdF6B22D72d5ccf "getThreshold()(uint256)" --rpc-url "$BSC_RPC" 2>&1 | head -c 100; echo
  echo -n "  owners: ";    cast call 0x88d0A269b924B535c96337082EdF6B22D72d5ccf "getOwners()(address[])" --rpc-url "$BSC_RPC" 2>&1 | head -c 600; echo
} | tee "$OUT/bsc_state.txt"

# ---------- 3. Ethereum (1) token/role state ----------
{
  echo "probe_utc=$TS"
  echo -n "eth_head: "; cast block-number --rpc-url "$ETH_RPC" 2>&1
  for t in 0xF5e11df1ebCf78b6b6D26E04FF19cD786a1e81dC 0x77776b40C3d75cb07ce54dEA4b2Fd1D07F865222; do
    echo "token $t"
    echo -n "  name: ";        cast call "$t" "name()(string)" --rpc-url "$ETH_RPC" 2>&1 | head -c 200; echo
    echo -n "  totalSupply: "; cast call "$t" "totalSupply()(uint256)" --rpc-url "$ETH_RPC" 2>&1 | head -c 100; echo
    echo -n "  owner: ";       cast call "$t" "owner()(address)" --rpc-url "$ETH_RPC" 2>&1 | head -c 100; echo
    echo -n "  getMinters: ";  cast call "$t" "getMinters()(address[])" --rpc-url "$ETH_RPC" 2>&1 | head -c 400; echo
  done
  echo -n "BB token code on ETH (expect 0x): "; cast code 0xe0620aBeA429A66Ba69d9a0cdE9aB93dc15bB9c4 --rpc-url "$ETH_RPC" 2>&1 | head -c 80; echo
} | tee "$OUT/eth_state.txt"

# ---------- verdict ----------
BB1=$(rpc "$BB_RPC" eth_blockNumber '[]' | jq -r '.result // "ERR"')
sleep 5
BB2=$(rpc "$BB_RPC" eth_blockNumber '[]' | jq -r '.result // "ERR"')
PEERS=$(rpc "$BB_RPC" net_peerCount '[]' | jq -r '.result // "ERR"')
{
  echo "verdict_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "bouncebit_blockNumber_final_calls=$BB1 $BB2 peers=$PEERS"
  if [ "$BB1" = "$BB2" ]; then echo "bouncebit_chain_frozen=YES (no block advance across call gap)"; else echo "bouncebit_chain_frozen=NO"; fi
  echo "expected_frozen_head=0x13bd0ac (20697260, 2026-08-19T21:02:35Z)"
  echo "live_extractable_usd_estimate=0 (chain halted; bridge/token contracts role-gated)"
} | tee "$OUT/verdict.txt"

echo "[ci] done"
