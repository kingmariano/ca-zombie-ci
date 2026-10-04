#!/bin/bash
# Read NETTFarm + ScoresFarm state at pinned block
RPC="https://andromeda.metis.io/?owner=1088"
BLK="${BLK:-23238721}"
OUT="raw/farms_state.txt"
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
r(){ cast call --rpc-url "$RPC" --block "$BLK" "$1" "$2" "${@:3}" 2>&1; }

NETT=0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052
SCORES=0xC92819F6497708D805F37FFFD082FE46E10Cac27
PAIRA=0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1

say "== NETTFarm $NETT (block $BLK) =="
say "owner: $(r $NETT 'owner()(address)')"
say "devAddr: $(r $NETT 'devAddr()(address)')"
say "nett: $(r $NETT 'nett()(address)')"
say "nettPerSec: $(r $NETT 'nettPerSec()(uint256)')"
say "startTimestamp: $(r $NETT 'startTimestamp()(uint256)')"
say "totalAllocPoint: $(r $NETT 'totalAllocPoint()(uint256)')"
say "devPercent: $(r $NETT 'devPercent()(uint256)')"
say "poolLength: $(r $NETT 'poolLength()(uint256)')"
say "NETT bal of farm: $(r 0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278 'balanceOf(address)(uint256)' $NETT)"
PL=$(r $NETT 'poolLength()(uint256)')
for i in $(seq 0 $((PL-1))); do
  say "pool[$i]: $(r $NETT 'poolInfo(uint256)(address,uint256,uint256,uint256,uint256,address)' $i | tr '\n' ' ')"
done

say ""
say "== ScoresFarm $SCORES (block $BLK) =="
say "owner: $(r $SCORES 'owner()(address)')"
say "startTimestamp: $(r $SCORES 'startTimestamp()(uint256)')"
say "endTimestamp: $(r $SCORES 'endTimestamp()(uint256)')"
say "scoresPerSec: $(r $SCORES 'scoresPerSec()(uint256)')"
say "totalAllocPoint: $(r $SCORES 'totalAllocPoint()(uint256)')"
say "remainingScores: $(r $SCORES 'remainingScores()(uint256)')"
say "poolLength: $(r $SCORES 'poolLength()(uint256)')"
say "LP bal pairA of farm: $(r $PAIRA 'balanceOf(address)(uint256)' $SCORES)"
SL=$(r $SCORES 'poolLength()(uint256)')
for i in $(seq 0 $((SL-1))); do
  say "pool[$i]: $(r $SCORES 'poolInfo(uint256)(address,uint256,uint256,uint256,uint256)' $i | tr '\n' ' ')"
done
