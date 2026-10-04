#!/usr/bin/env bash
# H-39 / H-40 — Harmony orphan contracts: CI helper (read-only).
# Probes for a working Harmony RPC, exports HARMONY_RPC_URL for the forge test step,
# and snapshots live on-chain state into ci-out/ (uploaded as artifacts).
set -uo pipefail

FOLDER="$(pwd)"
mkdir -p ci-out
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

probe() {
  for rpc in "https://api.harmony.one" "https://rpc.s0.t.hmny.io" "https://1rpc.io/one" "https://harmony.public-rpc.com"; do
    bn=$(curl -s -m 15 -A "$UA" -X POST "$rpc" -H 'Content-Type: application/json' \
          -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
          | python3 -c "import json,sys;print(int(json.load(sys.stdin)['result'],16))" 2>/dev/null)
    if [ -n "${bn:-}" ]; then echo "$rpc|$bn"; return 0; fi
  done
  return 1
}

PICK=$(probe || true)
if [ -z "$PICK" ]; then
  echo "[ci] WARNING: no Harmony RPC reachable; tests will fall back to default"
  RPC="https://api.harmony.one"; BLK="unknown"
else
  RPC="${PICK%%|*}"; BLK="${PICK##*|}"
  echo "HARMONY_RPC_URL=$RPC" >> "$GITHUB_ENV"
fi
echo "[ci] harmony rpc=$RPC block=$BLK"
echo "$RPC" > ci-out/rpc-used.txt
echo "$BLK" > ci-out/block.txt

OFT_BSC=0x5B18a4E73F9A4fe337A072516b317863Ad3046aA
OFT_ETH=0x905582f21fB9855c809d5b8933272a292dfbB138
OWNER=0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C
LZ_EP=0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4
SAFE_A=0x85049A5abed20A50d587C113F1Ef03d0Fd796453
SAFE_B=0x3Ef056E3220f270f4815219Dc1cF2A1854b96d80
SAFE_C=0x399b8bB5d6677B557345D4D2c7a3B1986E448bAf
SAFE_D=0x59f93F30fc4B1429E2016DB36346299d80927690

{
  echo "harmony_block=$BLK"
  echo "rpc=$RPC"
  for a in "$OFT_BSC" "$OFT_ETH" "$SAFE_A" "$SAFE_B" "$SAFE_C" "$SAFE_D" "$OWNER" "$LZ_EP"; do
    echo "balance[$a]=$(cast balance "$a" --rpc-url "$RPC" 2>/dev/null)"
  done
  for a in "$OFT_BSC" "$OFT_ETH"; do
    echo "totalSupply[$a]=$(cast call "$a" 'totalSupply()(uint256)' --rpc-url "$RPC" 2>/dev/null)"
    echo "balanceOfSelf[$a]=$(cast call "$a" 'balanceOf(address)(uint256)' "$a" --rpc-url "$RPC" 2>/dev/null)"
    echo "owner[$a]=$(cast call "$a" 'owner()(address)' --rpc-url "$RPC" 2>/dev/null)"
    echo "trustedRemoteLookup101[$a]=$(cast call "$a" 'trustedRemoteLookup(uint16)(bytes)' 101 --rpc-url "$RPC" 2>/dev/null)"
    echo "trustedRemoteLookup102[$a]=$(cast call "$a" 'trustedRemoteLookup(uint16)(bytes)' 102 --rpc-url "$RPC" 2>/dev/null)"
  done
  for s in "$SAFE_A" "$SAFE_B" "$SAFE_C" "$SAFE_D"; do
    echo "threshold[$s]=$(cast call "$s" 'getThreshold()(uint256)' --rpc-url "$RPC" 2>/dev/null)"
    echo "nonce[$s]=$(cast call "$s" 'nonce()(uint256)' --rpc-url "$RPC" 2>/dev/null)"
    echo "version[$s]=$(cast call "$s" 'VERSION()(string)' --rpc-url "$RPC" 2>/dev/null)"
  done
  echo "oft_bsc_code_keccak=$(cast keccak "$(cast code "$OFT_BSC" --rpc-url "$RPC" 2>/dev/null)")"
  echo "oft_eth_code_keccak=$(cast keccak "$(cast code "$OFT_ETH" --rpc-url "$RPC" 2>/dev/null)")"
  echo "lz_endpoint_code_len=$(cast code "$LZ_EP" --rpc-url "$RPC" 2>/dev/null | wc -c)"
} > ci-out/state.txt 2>&1

cat ci-out/state.txt
echo "[ci] snapshot written to ci-out/state.txt"
