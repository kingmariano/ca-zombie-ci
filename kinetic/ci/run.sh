#!/usr/bin/env bash
# ci/run.sh — Kinetic (Flare) C2-12: probe a working Flare RPC, pin it for the foundry fork tests,
# and dump a live-state snapshot artifact. Read-only; no transactions.
set -uo pipefail
cd "$(dirname "$0")/.."   # kinetic/
mkdir -p ci-out

PROBE='{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
PICK=""
for u in "https://flare.public-rpc.com" "https://flare-api.flare.network/ext/C/rpc" \
         "https://rpc.ankr.com/flare" "https://14.rpc.thirdweb.com" "https://flare.drpc.org"; do
  r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' --data "$PROBE" "$u" 2>/dev/null)
  case "$r" in *result*) PICK="$u"; break;; esac
done
if [ -z "$PICK" ]; then
  echo "WARNING: no Flare RPC reachable; tests will fall back to hardcoded list"
else
  echo "$PICK" > poc/.rpc
  echo "[ci] flare rpc = $PICK"
fi

RPC="${PICK:-https://flare.public-rpc.com}"
BLK=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo "?")

C1=0x15F69897E6aEBE0463401345543C26d1Fd994abB
C2=0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8
C3=0xDcce91d46Ecb209645A26B5885500127819BeAdd
C4=0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f

WORK=$(mktemp -d)
CMDS="$WORK/cmds.txt"
: > "$CMDS"

# header
{
  echo "# Kinetic live state snapshot"
  echo "# rpc=$RPC block=$BLK time=$(date -u +%FT%TZ)"
} > ci-out/live-state-snapshot.txt

add_market_calls() {
  local C="$1" M="$2"
  local id="$(echo "$M" | tr 'A-Z' 'a-z')"
  echo "echo \"\$(${CAST_BIN} call $M 'symbol()(string)' --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.sym" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $M 'getCash()(uint256)' --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.cash" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $M 'totalSupply()(uint256)' --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.sup" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $M 'totalBorrows()(uint256)' --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.bor" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $M 'exchangeRateStored()(uint256)' --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.rate" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $C 'markets(address)(bool,uint256)' $M --rpc-url $RPC 2>/dev/null | tr '\\n' ' ')\" > $WORK/$id.cf" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $C 'mintGuardianPaused(address)(bool)' $M --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.mp" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $C 'borrowGuardianPaused(address)(bool)' $M --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.bp" >> "$CMDS"
  echo "echo \"\$(${CAST_BIN} call $C 'borrowCaps(address)(uint256)' $M --rpc-url $RPC 2>/dev/null)\" > $WORK/$id.cap" >> "$CMDS"
}

# find cast binary (foundryup installs to ~/.foundry/bin)
CAST_BIN=$(command -v cast || echo "$HOME/.foundry/bin/cast")
export WORK RPC CAST_BIN

for C in $C1 $C2 $C3 $C4; do
  MK=$(cast call $C 'getAllMarkets()(address[])' --rpc-url "$RPC" 2>/dev/null | tr -d '[]' | tr ',' ' ')
  for M in $MK; do add_market_calls "$C" "$M"; done
done

# run all market calls in parallel
cat "$CMDS" | xargs -P 16 -I{} bash -c 'eval "$1"' _ {} >/dev/null 2>&1

# assemble
for C in $C1 $C2 $C3 $C4; do
  {
    echo "=== comptroller $C ==="
    echo "oracle=$(cast call $C 'oracle()(address)' --rpc-url "$RPC" 2>/dev/null)"
    echo "admin=$(cast call $C 'admin()(address)' --rpc-url "$RPC" 2>/dev/null)"
    echo "impl=$(cast call $C 'comptrollerImplementation()(address)' --rpc-url "$RPC" 2>/dev/null)"
  } >> ci-out/live-state-snapshot.txt
  MK=$(cast call $C 'getAllMarkets()(address[])' --rpc-url "$RPC" 2>/dev/null | tr -d '[]' | tr ',' ' ')
  for M in $MK; do
    id="$(echo "$M" | tr 'A-Z' 'a-z')"
    echo "$M $(cat $WORK/$id.sym 2>/dev/null) cash=$(cat $WORK/$id.cash 2>/dev/null) supply=$(cat $WORK/$id.sup 2>/dev/null) borrows=$(cat $WORK/$id.bor 2>/dev/null) rate=$(cat $WORK/$id.rate 2>/dev/null) cf=[$(cat $WORK/$id.cf 2>/dev/null)] mintPaused=$(cat $WORK/$id.mp 2>/dev/null) borrowPaused=$(cat $WORK/$id.bp 2>/dev/null) cap=$(cat $WORK/$id.cap 2>/dev/null)" >> ci-out/live-state-snapshot.txt
  done
done

{
  echo "=== FTSO feeds (FtsoV2 0x7BDE3Df0624114eDB3A67dFe6753e62f4e7c1d20) ==="
  for f in 0x01464c522f55534400000000000000000000000000 0x01555344542f555344000000000000000000000000 0x014554482f55534400000000000000000000000000; do
    echo "$f -> $(cast call 0x7BDE3Df0624114eDB3A67dFe6753e62f4e7c1d20 'getFeedById(bytes21)(uint256,int8,uint64)' $f --rpc-url "$RPC" 2>/dev/null | tr '\n' ' ')"
  done
} >> ci-out/live-state-snapshot.txt

rm -rf "$WORK"
echo "[ci] snapshot written: ci-out/live-state-snapshot.txt ($(wc -l < ci-out/live-state-snapshot.txt) lines)"
