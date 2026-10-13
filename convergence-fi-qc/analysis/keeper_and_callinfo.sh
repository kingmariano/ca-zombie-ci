#!/usr/bin/env bash
# (a) all services withdrawCallInfo slots; (b) pending gauge rewards; (c) weekly window.
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
R="${BLOCKPI_RPC_URL:-$RPC_URL}"
OUT=keeper_and_callinfo.txt
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
T=0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7
CR=0xa044fd2E8254eC5DE93B15b8B27d005899579109
BH=0x21777106355Ba506A31FF7984c0aE5C924deB77f

say "block=$(cast block-number --rpc-url "$R") ts=$(cast block latest --field timestamp --rpc-url "$R")"
say "cvgRewards.lastUpdatedTimestamp=$(cast call $CR 'lastUpdatedTimestamp()(uint256)' --rpc-url "$R" 2>&1)"
say "cvgRewards.state=$(cast call $CR 'state()(uint8)' --rpc-url "$R" 2>&1)"
SERVICES=$(cast call $T "getSdtStakings(uint256,uint256)((address,string)[])" 0 1000 --rpc-url "$R" | tr ',' '\n' | grep -oE '0x[0-9a-fA-F]{40}' | head -37)
say "=== withdrawCallInfo (slot160 addr / slot161 sig) per service ==="
i=0
for s in $SERVICES; do
  i=$((i+1))
  a=$(cast storage $s 160 --rpc-url "$R" | tail -c 41)
  g=$(cast storage $s 161 --rpc-url "$R")
  say "svc$i $s callAddr=$a sig=$g"
done
say "=== pending gauge rewards for processable services (isSdtProcessed=false, totalStaked>0) ==="
i=0
for s in $SERVICES; do
  i=$((i+1))
  ci=$(cast call $s "cycleInfo(uint256)(uint256,uint256,bool)" 140 --rpc-url "$R" 2>/dev/null | tr '\n' ' ')
  proc=$(echo $ci | awk '{print $3}')
  tot=$(echo $ci | awk '{print $2}')
  if [ "$proc" = "false" ] && [ "$tot" != "0" ]; then
    g=$(cast call $s "stakingAsset()(address)" --rpc-url "$R" 2>/dev/null)
    rc=$(cast call $g "reward_count()(uint256)" --rpc-url "$R" 2>/dev/null)
    say "svc$i $s gauge=$g totalStaked=$tot reward_count=$rc"
    if [ -n "$rc" ] && [ "$rc" != "0" ]; then
      n=0
      while [ $n -lt $rc ]; do
        tok=$(cast call $g "reward_tokens(uint256)(address)" $n --rpc-url "$R" 2>/dev/null)
        if [ -n "$tok" ] && [ "$tok" != "0x0000000000000000000000000000000000000000" ]; then
          cr=$(cast call $g "claimable_reward(address,address)(uint256)" $BH $tok --rpc-url "$R" 2>/dev/null)
          say "   reward_tokens[$n]=$tok claimable(blackhole)=$cr"
        fi
        n=$((n+1))
      done
    fi
    # bribes
    buf=$(cast call $s "buffer()(address)" --rpc-url "$R" 2>/dev/null)
    bt=$(cast call $BH "getBribeTokensForBuffer(address)((address,uint96)[])" $buf --rpc-url "$R" 2>&1 | head -1)
    say "   buffer=$buf bribeTokens=$bt"
  fi
done
say "=== sdCRV gauge claimable for blackhole (next-cycle bounty base) ==="
G1=0x7f50786A0b15723D741727882ee99a0BF34e3466
rc=$(cast call $G1 "reward_count()(uint256)" --rpc-url "$R" 2>/dev/null)
say "sdCRV reward_count=$rc"
n=0
while [ $n -lt ${rc:-0} ]; do
  tok=$(cast call $G1 "reward_tokens(uint256)(address)" $n --rpc-url "$R" 2>/dev/null)
  cr=$(cast call $G1 "claimable_reward(address,address)(uint256)" $BH $tok --rpc-url "$R" 2>/dev/null)
  say "  sdCRV reward[$n]=$tok claimable=$cr"
  n=$((n+1))
done
say "=== done ==="
