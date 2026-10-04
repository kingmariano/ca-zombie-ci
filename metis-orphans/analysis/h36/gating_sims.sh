#!/usr/bin/env bash
set -u
RPC='https://andromeda.metis.io/?owner=1088'
B=23238718
V=0x17A30350771d02409046A683b18Fe1C13cCFC4A8
PAYER_ROLE=0x8ec07e268e32cae7f300b49ad34f20106d088445cb9d9b2d62cbd864638308b2
PAYEE_ROLE=0x95ed160efa56927d40641b26c79df8395a2e4f8f170168fedfa462234b4c3a46
ATT=0x1111111111111111111111111111111111111111
PAYER_EOA=0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1
PAYER_CTR=0x96ED493C74e23e4FAAd2409e59eD2d4eC8f64E52
PAYEE1=0xD6216fC19DB775Df9774a6E33526131dA7D19a2c
PAYEE2=0xC519c75cF9DE75311E6797cB3a3c641a01bdB1d5

try(){ # name, from, sig, args...
  local name=$1 from=$2 sig=$3; shift 3
  local out rc
  out=$(cast call $V "$sig" "$@" --from $from --block $B --rpc-url "$RPC" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then echo "PASS | $name | from=$from | out=$out"; else echo "REVERT($rc) | $name | from=$from | err=$(echo "$out" | tr '\n' ' ' | sed 's/Error: //')"; fi
}

try "initialize()" $ATT "initialize()"
try "transferEther(rand,1)" $ATT "transferEther(address,uint256)" 0x2222222222222222222222222222222222222222 1
try "upgradeTo(rand)" $ATT "upgradeTo(address)" 0x3333333333333333333333333333333333333333
try "upgradeToAndCall(rand,0x)" $ATT "upgradeToAndCall(address,bytes)" 0x3333333333333333333333333333333333333333 0x
try "unknown-selector-0xdeadbeef" $ATT "0xdeadbeef"
try "grantRole(PAYER,att)" $ATT "grantRole(bytes32,address)" $PAYER_ROLE $ATT
try "grantRole(ADMIN,att)" $ATT "grantRole(bytes32,address)" 0x0000000000000000000000000000000000000000000000000000000000000000 $ATT
try "renounceOwnership" $ATT "renounceOwnership()"
try "PAYER_EOA->PAYEE1 1wei" $PAYER_EOA "transferEther(address,uint256)" $PAYEE1 1
try "PAYER_EOA->rand 1wei" $PAYER_EOA "transferEther(address,uint256)" 0x2222222222222222222222222222222222222222 1
try "PAYER_CTR->PAYEE1 1wei" $PAYER_CTR "transferEther(address,uint256)" $PAYEE1 1
try "ATT->PAYEE1 1wei" $ATT "transferEther(address,uint256)" $PAYEE1 1
try "onERC721Received" $ATT "onERC721Received(address,address,uint256,bytes)" $ATT $ATT 0 0x
try "hasRole(PAYER,PAYER_CTR)" $ATT "hasRole(bytes32,address)(bool)" $PAYER_ROLE $PAYER_CTR
echo "--- owner slot scan 40..70 ---"
for s in $(seq 40 70); do h=$(cast to-hex $s); val=$(cast storage $V $h --block $B --rpc-url "$RPC"); if [ "$val" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then echo "slot $s ($h): $val"; fi; done
