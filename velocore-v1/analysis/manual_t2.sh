#!/usr/bin/env bash
# Manual T2 (fresh fork): create pair -> gauge -> lock -> vote -> distribute
set -uo pipefail
FORK=http://127.0.0.1:8011
VC=0x85D84c774CF8e9fF85342684b0E795Df72A24908
ESC=0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F
VOTER=0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A
FACTORY=0xE140EaC2bB748c8F456719a457F26636617Bb0E9
USDC=0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4
ZKDOGE=0xbfb4b5616044eded03e5b1ad75141f0d9cb1499b
A=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
step() { echo; echo "== $*"; }
chk() { cast call "$1" "$2" ${3:-} --rpc-url $FORK 2>/dev/null | awk '{print $1}'; }
retry_read() { # addr sig [arg] expected_regex
  local i v; for i in $(seq 1 15); do
    v=$(chk "$1" "$2" "${3:-}")
    if echo "$v" | grep -qiE "$4"; then echo "$v"; return 0; fi
    sleep 1
  done; echo "$v"; }


step "0. fork state"
echo "block: $(cast block latest --field number --rpc-url $FORK) ts: $(cast block latest --field timestamp --rpc-url $FORK)"
echo "allPairsLength: $(chk $FACTORY 'allPairsLength()(uint256)')"

step "1. cheat VC + lock"
SLOT=$(cast index address $A 1)
curl -s -X POST $FORK -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"anvil_setStorageAt\",\"params\":[\"$VC\",\"$SLOT\",\"0x0000000000000000000000000000000000000000000422ca8b0a00a425000000\"]}" >/dev/null
echo "attacker VC: $(chk $VC 'balanceOf(address)(uint256)' $A)"
cast send $VC "approve(address,uint256)" $ESC 5000000000000000000000000 --private-key $PK --gas-limit 1000000 --rpc-url $FORK | grep -E '^status'
cast send $ESC "create_lock(uint256,uint256)" 5000000000000000000000000 125000000 --private-key $PK --gas-limit 3000000 --rpc-url $FORK | grep -E '^status'
TID=$(chk $ESC 'tokenOfOwnerByIndex(address,uint256)(uint256)' "$A 0")
BAL=$(chk $ESC 'balanceOfNFT(uint256)(uint256)' $TID)
echo "veNFT $TID balance $BAL lastVoted: $(chk $VOTER 'lastVoted(uint256)(uint256)' $TID)"

step "2. createPair(USDC, ZKDOGE, false)"
cast send $FACTORY "createPair(address,address,bool)" $USDC $ZKDOGE false --private-key $PK --gas-limit 20000000 --rpc-url $FORK | grep -E '^status'
N=$(chk $FACTORY 'allPairsLength()(uint256)')
NP=$(chk $FACTORY 'allPairs(uint256)(address)' $((N-1)))
echo "pair count $N; new pool: $NP"

step "3. createGauge(newPool)"
cast send $VOTER "createGauge(address)" $NP --private-key $PK --gas-limit 20000000 --rpc-url $FORK | grep -E '^status'
NG=$(retry_read $VOTER 'gauges(address)(address)' $NP '^0x[0-9a-f]{40}$')
echo "new gauge: $NG alive: $(chk $VOTER 'isAlive(address)(bool)' $NG)"

step "4. vote"
cast send $VOTER "vote(uint256,address[],uint256[])" $TID "[$NP]" "[$BAL]" --private-key $PK --gas-limit 20000000 --rpc-url $FORK | grep -E '^status'
W=$(retry_read $VOTER 'weights(address)(uint256)' $NP '^[1-9]')
echo "weights(newPool): $W"
echo "totalWeight: $(chk $VOTER 'totalWeight()(uint256)')"
echo "lastVoted: $(chk $VOTER 'lastVoted(uint256)(uint256)' $TID)"

step "5. distribute"
IDXB=$(cast storage $VOTER 18 --rpc-url $FORK)
GB=$(chk $VC 'balanceOf(address)(uint256)' $NG)
cast send $VOTER "distribute(address[])" "[$NG]" --private-key $PK --gas-limit 20000000 --rpc-url $FORK | grep -E '^status'
IDXA=$(cast storage $VOTER 18 --rpc-url $FORK)
GA=$(chk $VC 'balanceOf(address)(uint256)' $NG)
echo "index: $IDXB -> $IDXA"
echo "gauge VC: $GB -> $GA  (delta $(python3 -c "print(($GA-$GB)/1e18)"))"
echo "claimable(newGauge): $(chk $VOTER 'claimable(address)(uint256)' $NG)"
