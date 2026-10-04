#!/bin/bash
# Rewarder deep-dive: rates, times, ghost-user check
RPC="https://andromeda.metis.io/?owner=1088"
BLK=23238721
OUT="raw/rewarder_state.txt"
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
r(){ cast call --rpc-url "$RPC" --block "$BLK" "$1" "$2" "${@:3}" 2>&1; }

FARM=0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052
REWARDS="0x4CCceDE3d5A6fc96FF921b8E765446c827f4B294 0x1DdF972f2cCBF896B4df62bEfb434f7e9F553634 0x876488D7BEb48EDe40E74346a70FE587E8F7da66 0xD8A5EE9C79f8b095653B60d19939bC7Db4236E08"
PIDS="21 22 23 24"

say "== rewarders =="
for R in $REWARDS; do
  say "-- $R"
  say "rewardToken: $(r $R 'rewardToken()(address)')"
  say "lpToken: $(r $R 'lpToken()(address)')"
  say "isNative: $(r $R 'isNative()(bool)')"
  say "NTF: $(r $R 'NTF()(address)')"
  say "tokenPerSec: $(r $R 'tokenPerSec()(uint256)')"
  say "startTime: $(r $R 'startTime()(uint256)')"
  say "endTime: $(r $R 'endTime()(uint256)')"
  say "duration: $(r $R 'duration()(uint256)')"
  say "owner: $(r $R 'owner()(address)')"
  say "METIS bal: $(r 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000 'balanceOf(address)(uint256)' $R)"
  say "poolInfo: $(r $R 'poolInfo()(uint256,uint256)')"
done

say ""
say "== farm pools 21-24 lpSupply vs farm LP balance =="
for i in $PIDS; do
  LP=$(r $FARM 'poolInfo(uint256)(address,uint256,uint256,uint256,uint256,address)' $i | sed -n 1p)
  SUP=$(r $FARM 'poolInfo(uint256)(address,uint256,uint256,uint256,uint256,address)' $i | sed -n 5p)
  BAL=$(r $LP 'balanceOf(address)(uint256)' $FARM)
  say "pool[$i] lp=$LP lpSupply=$SUP farmBal=$BAL"
done

say ""
say "== EmergencyWithdraw events on farm (all pools) =="
EW=$(cast sig-event "EmergencyWithdraw(address,uint256,uint256)")
say "EW topic: $EW"
