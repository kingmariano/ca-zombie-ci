#!/usr/bin/env bash
set -u
RPC='https://andromeda.metis.io/?owner=1088'
B=23238718
V=0x17A30350771d02409046A683b18Fe1C13cCFC4A8
ADMIN=0x0000000000000000000000000000000000000000000000000000000000000000
PAYER=$(cast keccak PAYER_ROLE)
PAYEE=$(cast keccak PAYEE_ROLE)
echo "PAYER_ROLE=$PAYER"
echo "PAYEE_ROLE=$PAYEE"

members() {
  local role=$1 name=$2
  local count
  count=$(cast call $V "getRoleMemberCount(bytes32)(uint256)" $role --block $B --rpc-url "$RPC")
  echo "$name count=$count"
  local i=0 out="[]"
  while [ "$i" -lt "$count" ]; do
    local m
    m=$(cast call $V "getRoleMember(bytes32,uint256)(address)" $role $i --block $B --rpc-url "$RPC")
    local cs
    cs=$(cast codesize $m --block $B --rpc-url "$RPC")
    local ch
    ch=$(cast codehash $m --block $B --rpc-url "$RPC")
    local hr
    hr=$(cast call $V "hasRole(bytes32,address)(bool)" $role $m --block $B --rpc-url "$RPC")
    echo "  [$i] $m codesize=$cs codehash=$ch hasRole=$hr"
    i=$((i+1))
  done
}

members $ADMIN DEFAULT_ADMIN_ROLE
members $PAYER PAYER_ROLE
members $PAYEE PAYEE_ROLE

echo "--- slot scan for owner/packing ---"
for s in 0 1 2 3 4 5 6 7 8 9 10; do
  echo "slot $s: $(cast storage $V $(cast to-hex $s) --block $B --rpc-url "$RPC")"
done
echo "--- getRoleAdmin checks ---"
echo "admin->admin: $(cast call $V "getRoleAdmin(bytes32)(bytes32)" $ADMIN --block $B --rpc-url "$RPC")"
echo "payer->admin: $(cast call $V "getRoleAdmin(bytes32)(bytes32)" $PAYER --block $B --rpc-url "$RPC")"
echo "payee->admin: $(cast call $V "getRoleAdmin(bytes32)(bytes32)" $PAYEE --block $B --rpc-url "$RPC")"
