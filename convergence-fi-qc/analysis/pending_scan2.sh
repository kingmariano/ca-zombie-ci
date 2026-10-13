#!/usr/bin/env bash
# Corrected pending-rewards scan: parse cast output with awk '{print $NF}' for bool.
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
R="${BLOCKPI_RPC_URL:-$RPC_URL}"
OUT=pending_scan2.txt
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }
T=0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7
BH=0x21777106355Ba506A31FF7984c0aE5C924deB77f
SERVICES=$(cast call $T "getSdtStakings(uint256,uint256)((address,string)[])" 0 1000 --rpc-url "$R" | tr ',' '\n' | grep -oE '0x[0-9a-fA-F]{40}' | head -37)
say "block=$(cast block-number --rpc-url "$R")"
i=0
for s in $SERVICES; do
  i=$((i+1))
  raw=$(cast call $s "cycleInfo(uint256)(uint256,uint256,bool)" 140 --rpc-url "$R" 2>/dev/null)
  tot=$(echo "$raw" | sed -n 2p)
  proc=$(echo "$raw" | tail -1)
  if [ "$proc" = "false" ] && [ -n "$tot" ] && [ "$tot" != "0" ]; then
    g=$(cast call $s "stakingAsset()(address)" --rpc-url "$R" 2>/dev/null)
    name=$(cast call $s "symbol()(string)" --rpc-url "$R" 2>/dev/null)
    say "svc$i $s sym=$name gauge=$g totalStaked=$tot"
    rc=$(cast call $g "reward_count()(uint256)" --rpc-url "$R" 2>/dev/null)
    n=0
    while [ $n -lt ${rc:-0} ]; do
      tok=$(cast call $g "reward_tokens(uint256)(address)" $n --rpc-url "$R" 2>/dev/null)
      cr=$(cast call $g "claimable_reward(address,address)(uint256)" $BH $tok --rpc-url "$R" 2>/dev/null)
      say "   tok[$n]=$tok claimable=$cr"
      n=$((n+1))
    done
    buf=$(cast call $s "buffer()(address)" --rpc-url "$R" 2>/dev/null)
    say "   buffer=$buf"
  fi
done
say "=== bribe tokens per buffer of processable services ==="
i=0
for s in $SERVICES; do
  i=$((i+1))
  raw=$(cast call $s "cycleInfo(uint256)(uint256,uint256,bool)" 140 --rpc-url "$R" 2>/dev/null)
  tot=$(echo "$raw" | sed -n 2p); proc=$(echo "$raw" | tail -1)
  if [ "$proc" = "false" ] && [ -n "$tot" ] && [ "$tot" != "0" ]; then
    buf=$(cast call $s "buffer()(address)" --rpc-url "$R" 2>/dev/null)
    bt=$(cast call $BH "getBribeTokensForBuffer(address)((address,uint96)[])" $buf --rpc-url "$R" 2>&1)
    say "svc$i buf=$buf bribes=$bt"
  fi
done
say "=== done ==="
