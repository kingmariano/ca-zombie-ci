#!/usr/bin/env bash
set -u
RPC='https://andromeda.metis.io/?owner=1088'
B=23238718
V=0x17A30350771d02409046A683b18Fe1C13cCFC4A8
IMPL_SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
ADMIN_SLOT=0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
BEACON_SLOT=0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
log(){ echo "$*"; }

BLK_JSON=$(cast block $B --json --rpc-url "$RPC")
BLK_HASH=$(echo "$BLK_JSON" | jq -r .hash)
BLK_TS=$(echo "$BLK_JSON" | jq -r .timestamp)

impl_raw=$(cast storage $V $IMPL_SLOT --block $B --rpc-url "$RPC")
impl_addr=0x${impl_raw: -40}
admin_raw=$(cast storage $V $ADMIN_SLOT --block $B --rpc-url "$RPC")
beacon_raw=$(cast storage $V $BEACON_SLOT --block $B --rpc-url "$RPC")
slot0=$(cast storage $V 0x0 --block $B --rpc-url "$RPC")
bal=$(cast balance $V --block $B --rpc-url "$RPC")
bal_eth=$(cast from-wei $bal)
owner=$(cast call $V "owner()(address)" --block $B --rpc-url "$RPC" 2>err_owner.txt) || owner="REVERT:$(cat err_owner.txt)"
payercount=$(cast call $V "getRoleMemberCount(bytes32)(uint256)" $(cast keccak PAYER_ROLE) --block $B --rpc-url "$RPC")
payeecount=$(cast call $V "getRoleMemberCount(bytes32)(uint256)" $(cast keccak PAYEE_ROLE) --block $B --rpc-url "$RPC")
admincount=$(cast call $V "getRoleMemberCount(bytes32)(uint256)" 0x0000000000000000000000000000000000000000000000000000000000000000 --block $B --rpc-url "$RPC")
proxy_codehash=$(cast codehash $V --block $B --rpc-url "$RPC")
proxy_codesize=$(cast codesize $V --block $B --rpc-url "$RPC")
impl_codehash=$(cast codehash $impl_addr --block $B --rpc-url "$RPC")
impl_codesize=$(cast codesize $impl_addr --block $B --rpc-url "$RPC")

json=$(jq -n \
  --arg rpc "$RPC" --argjson block "$B" --arg block_hash "$BLK_HASH" --arg block_ts "$BLK_TS" \
  --arg V "$V" \
  --arg impl_slot "$IMPL_SLOT" --arg impl_raw "$impl_raw" --arg impl_addr "$impl_addr" \
  --arg admin_slot "$ADMIN_SLOT" --arg admin_raw "$admin_raw" \
  --arg beacon_slot "$BEACON_SLOT" --arg beacon_raw "$beacon_raw" \
  --arg slot0 "$slot0" \
  --arg bal_wei "$bal" --arg bal_metis "$bal_eth" \
  --arg owner "$owner" \
  --arg payer_count "$payercount" --arg payee_count "$payeecount" --arg admin_count "$admincount" \
  --arg proxy_codehash "$proxy_codehash" --argjson proxy_codesize "$proxy_codesize" \
  --arg impl_codehash "$impl_codehash" --argjson impl_codesize "$impl_codesize" \
  '{rpc:$rpc, block:$block, block_hash:$block_hash, block_timestamp:($block_ts|tonumber), proxy:$V,
    impl_slot:{slot:$impl_slot, raw:$impl_raw, address:$impl_addr},
    admin_slot:{slot:$admin_slot, raw:$admin_raw}, beacon_slot:{slot:$beacon_slot, raw:$beacon_raw},
    network_upgradeable_slot0:{slot:"0x0", raw:$slot0},
    balance:{wei:$bal_wei, metis:$bal_metis},
    owner:$owner,
    role_member_counts:{DEFAULT_ADMIN_ROLE:$admin_count, PAYER_ROLE:$payer_count, PAYEE_ROLE:$payee_count},
    code:{proxy_codehash:$proxy_codehash, proxy_codesize:$proxy_codesize, impl_codehash:$impl_codehash, impl_codesize:$impl_codesize}}')
echo "$json" > h36_state.json
log "$json"
