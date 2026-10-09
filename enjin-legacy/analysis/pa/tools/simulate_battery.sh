#!/bin/bash
# Enjin legacy CryptoItems PA/Adapter - read-only eth_call simulation battery.
# Never sends transactions. RPC from env ETH_RPC. Block: latest (26152497).
set -u
RPC="$ETH_RPC"
PA=0xfaafdc07907ff5120a76b34b731b278c38d6043c
MB=0x68ee930ea6ad962205f1e29ae79bcc3dfa07c837
AD=0x4e643a25a64952895f553f20252861258727174e
MGR=0xE5cb0C8E160C5aC4669D1dfD689Df01bA9eea3eB
ENJ=0xf629cbd94d3791c9250152bd8dfbdf380e2a3b9c
ATK=0x0000000000000000000000000000000000001111
VICTIM=0xB3FbC3b41D9606b8A9ecBeA57581E526AeF958Ad
ID1=36185027886661319085724848904006306622449963644202689625038397583044925980672
Z32=0x0000000000000000000000000000000000000000000000000000000000000000

run() {
  local label="$1"; shift
  echo "----------------------------------------------------------------"
  echo "## $label"
  echo "\$ cast call $*"
  out=$(cast call "$@" --rpc-url "$RPC" 2>&1)
  echo "$out" | head -c 900
  echo
}

echo "================================================================================"
echo "ENJIN LEGACY CRYPTOITEMS (PA 0xfaafdc07 / Adapter 0x4e64) - eth_call battery"
echo "block: latest = 26152497   attacker EOA = $ATK   (READ-ONLY SIMULATION)"
echo "================================================================================"

run "PA.safeTransferFrom(victim,attacker) from attacker" "$PA" "safeTransferFrom(address,address,uint256,uint256,bytes)" "$VICTIM" "$ATK" "$ID1" 1 0x --from "$ATK"
run "PA.safeTransferFrom(victim,attacker) from victim (legit owner, post-lock)" "$PA" "safeTransferFrom(address,address,uint256,uint256,bytes)" "$VICTIM" "$ATK" "$ID1" 1 0x --from "$VICTIM"
run "PA.melt([id],[1]) from attacker" "$PA" "melt(uint256[],uint256[])" "[$ID1]" "[1]" --from "$ATK"
run "PA.create(...) from attacker" "$PA" "create(string,uint256,uint256,address,uint256,uint16,uint8,uint256[3],bool)" "x" 0 0 "$ATK" 0 0 0 "[0,0,0]" false --from "$ATK"
run "PA.setURI(id,x) from attacker" "$PA" "setURI(uint256,string)" "$ID1" "x" --from "$ATK"
run "PA.assign(id,attacker) from attacker" "$PA" "assign(uint256,address)" "$ID1" "$ATK" --from "$ATK"
run "PA.releaseReserve(id,1) from attacker" "$PA" "releaseReserve(uint256,uint128)" "$ID1" 1 --from "$ATK"
run "PA.initialize(attacker) from attacker" "$PA" "initialize(address)" "$ATK" --from "$ATK"
run "PA.transferManager(attacker) from attacker" "$PA" "transferManager(address)" "$ATK" --from "$ATK"
run "PA.acceptManager() from attacker" "$PA" "acceptManager()" --from "$ATK"
run "PA.removeManager() from attacker" "$PA" "removeManager()" --from "$ATK"
run "moduleB 0x33d332ab(1,0x,0) direct from attacker" "$MB" "0x33d332ab" "$(cast to-uint256 1)" 0x "$(cast to-uint256 0)" --from "$ATK"
run "moduleB 0x41c1df0e(attacker,victim,attacker,id) direct from attacker" "$MB" "0x41c1df0e" "$ATK" "$VICTIM" "$ATK" "$ID1" --from "$ATK"
run "moduleB 0xf95d7da3(attacker,victim,attacker,id,1) direct from attacker" "$MB" "0xf95d7da3" "$ATK" "$VICTIM" "$ATK" "$ID1" 1 --from "$ATK"
run "Adapter.setUint(key,1) from attacker" "$AD" "setUint(bytes32,uint256)" "$Z32" 1 --from "$ATK"
run "Adapter.setUint(key,1) from PA (spoof control)" "$AD" "setUint(bytes32,uint256)" "$Z32" 1 --from "$PA"
run "Adapter.setAddress(key,attacker) from attacker" "$AD" "setAddress(bytes32,address)" "$Z32" "$ATK" --from "$ATK"
run "Adapter.addApprovedAddress(attacker) from attacker" "$AD" "addApprovedAddress(address)" "$ATK" --from "$ATK"
run "Adapter.removeApprovedAddress(attacker) from attacker" "$AD" "removeApprovedAddress(address)" "$ATK" --from "$ATK"
run "Adapter.mintFungible(id,attacker,1) from attacker" "$AD" "mintFungible(uint256,address,uint256)" "$ID1" "$ATK" 1 --from "$ATK"
run "Adapter.mintFungible(id,attacker,1) from PA (spoof control)" "$AD" "mintFungible(uint256,address,uint256)" "$ID1" "$ATK" 1 --from "$PA"
run "Adapter.releaseETH(attacker,1) from attacker" "$AD" "releaseETH(address,uint256)" "$ATK" 1 --from "$ATK"
run "Adapter.globalUnlock() from attacker" "$AD" "globalUnlock()" --from "$ATK"
run "Adapter.globalLock() from attacker" "$AD" "globalLock()" --from "$ATK"
run "Adapter.globalUnlock() from manager contract (spoof control)" "$AD" "globalUnlock()" --from "$MGR"
run "manager.lockStorage() from attacker" "$MGR" "lockStorage()" --from "$ATK"
run "manager.releaseERC20(ENJ,attacker,1e18) from attacker" "$MGR" "releaseERC20(address,address,uint256)" "$ENJ" "$ATK" 1000000000000000000 --from "$ATK"
echo "================================================================================"
echo "done"
