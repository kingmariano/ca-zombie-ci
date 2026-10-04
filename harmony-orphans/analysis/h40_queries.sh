#!/bin/bash
# H-40 Safe state sweep — read-only eth_call/storage. Block pinned 0x59497fb (93,624,315)
RPC="${RPC:-https://api.harmony.one}"
BLK="${BLK:-0x59497fb}"
OUT=/home/heisenberg/CA/harmony-orphans/analysis/h40_state_raw.txt
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

names=(A B C D)
safes=(0x85049A5abed20A50d587C113F1Ef03d0Fd796453 0x3Ef056E3220f270f4815219Dc1cF2A1854b96d80 0x399b8bB5d6677B557345D4D2c7a3B1986E448bAf 0x59f93F30fc4B1429E2016DB36346299d80927690)

# expected owners from context
ownersA=(0x4e4B14D9E67A4d5fbB9CDc812927822bd0593F07 0x010afBb46a1b9535e367d7c0EF9626CaB7C7f455 0x76c0e19F8DDBd00C8d40006474b97a92d7138197 0xbBE3e1d26d01768720637f9c76A26EdC7Ea35cD7 0xad7c1a92eEE50666E3f8b19Ca1d99111faE79850)
ownersB=(0xE48ec5A7468f155B0aBbE3BF910aA835B18aA7b4 0x26a4F6418b77650808D3F83e7e8A8f3B7f7C8B8c 0xc4093E4bFA5f1af9000376D84dABe6a93A121fA1 0x938E64c866203C8da6C160B82b5B634B821be88a)
ownersC=(0x0Ff2196e14F51C11c20251A9BD34398665E624d8 0xDEED0a305a10d86D1dd13F6cfAE9Cf471a93cf1E 0x4A0A8AE158D04F5c91483afe262DeF73C5E20b80 0x5e5F6A3FdfD7a5E4E9Bf5b7ca192bC3cB4A445DC 0x1AEA0FFE6B2ffE73B764515CEE1D933685CEBb25)
ownersD=(0xb042BA53d0F59EeE6C236143311eC31aBeA3AE98 0x9d75C2E7dBb55Ce3155d0Ab9d9c6672B11444C7F 0xF647CC574E360E2a7F9A0358FA5ea767781DfeA9 0x1E34cB671cBC63eF43E907BaeA790F143146eACe 0x0568ED3553b1df6da1B57e252aBa35ab68f1DD3c)
declare -A EO=( [A]="${ownersA[*]}" [B]="${ownersB[*]}" [C]="${ownersC[*]}" [D]="${ownersD[*]}" )

q(){ # q <safe> <label> <sig> [args...]
  local safe="$1" label="$2" sig="$3"; shift 3
  local o
  o=$(cast call "$safe" "$sig" "$@" --rpc-url "$RPC" --block "$BLK" 2>&1)
  local rc=$?
  if [ $rc -ne 0 ]; then o="REVERT/ERR: $(echo "$o" | head -2 | tr '\n' ' ')"; fi
  log "$label= $o"
}

# canonical code hashes
log "== BLOCK $BLK ; RPC $RPC ; $(date -u +%FT%TZ) =="
log "== factory/singleton =="
FACT=0xc22834581ebc8527d974f8a1c97e1bea4ef910bc
log "factory.proxyRuntimeCode()= $(cast call $FACT 'proxyRuntimeCode()(bytes)' --rpc-url $RPC --block $BLK 2>&1 | head -1)"
log "factory.proxyCreationCode()= $(cast call $FACT 'proxyCreationCode()(bytes)' --rpc-url $RPC --block $BLK 2>&1 | head -1)"

for i in 0 1 2 3; do
  n=${names[$i]}; s=${safes[$i]}
  log ""
  log "== SAFE $n $s =="
  log "$n.balance_wei= $(cast balance "$s" --rpc-url "$RPC" --block "$BLK" 2>&1)"
  q "$s" "$n.threshold" "getThreshold()(uint256)"
  q "$s" "$n.nonce" "nonce()(uint256)"
  q "$s" "$n.version" "VERSION()(string)"
  q "$s" "$n.owners" "getOwners()(address[])"
  q "$s" "$n.getModules_b2494df3" "getModules()(address[])"
  log "$n.rawsel_a7e5d5f1= $(cast call "$s" 0xa7e5d5f1 --rpc-url "$RPC" --block "$BLK" 2>&1 | head -2 | tr '\n' ' ')"
  q "$s" "$n.modulesPaginated" "getModulesPaginated(address,uint256)(address[],address)" 0x0000000000000000000000000000000000000001 100
  q "$s" "$n.guard" "getGuard()(address)"
  q "$s" "$n.fallbackHandler" "getFallbackHandler()(address)"
  for slot in 0 1 2 3 4 5; do
    log "$n.slot$slot= $(cast storage "$s" $slot --rpc-url "$RPC" --block "$BLK" 2>&1 | head -1)"
  done
  log "$n.code= $(cast code "$s" --rpc-url "$RPC" --block "$BLK" 2>&1 | head -c 90)... (keccak: $(cast code "$s" --rpc-url "$RPC" --block "$BLK" 2>/dev/null | cast keccak))"
  # owner EOA/contract + balances (unique union, dedup via assoc)
  for ow in ${EO[$n]}; do
    code=$(cast code "$ow" --rpc-url "$RPC" --block "$BLK" 2>/dev/null)
    osz=$(( (${#code} - 2) / 2 ))
    log "$n.owner $ow code_size=$osz keccak=$(printf '%s' "$code" | cast keccak 2>/dev/null) bal_wei=$(cast balance "$ow" --rpc-url "$RPC" --block "$BLK" 2>&1)"
  done
done
log ""
log "== ONE 0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C (OFT owner) =="
oc=$(cast code 0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C --rpc-url "$RPC" --block "$BLK" 2>/dev/null)
log "OFTowner.code_size= $(( (${#oc} - 2) / 2 )) keccak=$(printf '%s' "$oc" | cast keccak)"
log "OFTowner.balance= $(cast balance 0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C --rpc-url "$RPC" --block "$BLK" 2>&1)"
echo "DONE -> $OUT"
