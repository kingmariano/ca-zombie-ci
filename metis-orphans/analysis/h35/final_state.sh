#!/usr/bin/env bash
# Final live-state snapshot for H-35 — READ ONLY. Writes safe_state.json + owners.json
set -uo pipefail
RPC='https://andromeda.metis.io/?owner=1088'
SAFE=0xdd7c49D1bA862b1285710A30E20C2438b13AE532
SING=0xfb1bffc9d739b8d520daf37df666da4c687191ea
OUT=/home/heisenberg/CA/metis-orphans/analysis/h35
mkdir -p "$OUT"

B=$(cast block-number --rpc-url "$RPC")
BH=$(cast block "$B" --field hash --rpc-url "$RPC")
BT=$(cast block "$B" --field timestamp --rpc-url "$RPC")
BAL=$(cast balance "$SAFE" --block "$B" --rpc-url "$RPC")
NONCE=$(cast call "$SAFE" 'nonce()(uint256)' --block "$B" --rpc-url "$RPC")
THR=$(cast call "$SAFE" 'getThreshold()(uint256)' --block "$B" --rpc-url "$RPC")
VER=$(cast call "$SAFE" 'VERSION()(string)' --block "$B" --rpc-url "$RPC")
OWNC=$(cast to-dec $(cast storage "$SAFE" 3 --block "$B" --rpc-url "$RPC"))
OWNERS_RAW=$(cast call "$SAFE" 'getOwners()(address[])' --block "$B" --rpc-url "$RPC")
OWNERS_JSON=$(echo "$OWNERS_RAW" | tr -d '[] ' | tr ',' '\n' | jq -R . | jq -s .)
MOD=$(cast call "$SAFE" 'getModulesPaginated(address,uint256)(address[],address)' 0x0000000000000000000000000000000000000001 100 --block "$B" --rpc-url "$RPC" | head -1)
GUARD=$(cast storage "$SAFE" "$(cast keccak 'guard_manager.guard.address')" --block "$B" --rpc-url "$RPC")
FH=$(cast storage "$SAFE" "$(cast keccak 'fallback_manager.handler.address')" --block "$B" --rpc-url "$RPC")
SLOT0=$(cast storage "$SAFE" 0 --block "$B" --rpc-url "$RPC")
SCH=$(cast codehash "$SING" --block "$B" --rpc-url "$RPC")
SCSZ=$(cast codesize "$SING" --block "$B" --rpc-url "$RPC")
PCH=$(cast codehash "$SAFE" --block "$B" --rpc-url "$RPC")
PCSZ=$(cast codesize "$SAFE" --block "$B" --rpc-url "$RPC")
DS=$(cast call "$SAFE" 'domainSeparator()(bytes32)' --block "$B" --rpc-url "$RPC")

jq -n \
  --argjson chain_id 1088 \
  --arg rpc "$RPC" \
  --argjson block "$B" \
  --arg block_hash "$BH" \
  --argjson block_timestamp "$BT" \
  --arg safe "$SAFE" \
  --arg balance_wei "$BAL" \
  --arg nonce "$NONCE" \
  --arg threshold "$THR" \
  --arg version "$VER" \
  --arg owner_count_storage "$OWNC" \
  --argjson owners "$OWNERS_JSON" \
  --arg modules "$MOD" \
  --arg guard_storage_slot_value "$GUARD" \
  --arg fallback_handler_storage_slot_value "$FH" \
  --arg slot0 "$SLOT0" \
  --arg singleton "$SING" \
  --arg singleton_codehash "$SCH" \
  --argjson singleton_codesize "$SCSZ" \
  --arg proxy_codehash "$PCH" \
  --argjson proxy_codesize "$PCSZ" \
  --arg domain_separator "$DS" \
  '{chain_id:$chain_id, rpc:$rpc, block_number:$block, block_hash:$block_hash, block_timestamp:$block_timestamp,
    safe:$safe,
    balance_wei:$balance_wei,
    balance_metis:($balance_wei|tonumber/1e18),
    nonce:($nonce|tonumber), threshold:($threshold|tonumber), version:$version,
    owner_count:($owner_count_storage|tonumber), owners:$owners,
    modules:$modules,
    guard:($guard_storage_slot_value|ltrimstr("0x")|.[24:]),
    guard_is_zero:($guard_storage_slot_value=="0x0000000000000000000000000000000000000000000000000000000000000000"),
    fallback_handler:("0x"+($fallback_handler_storage_slot_value|ltrimstr("0x")|.[24:])),
    singleton:("0x"+($slot0|ltrimstr("0x")|.[24:])),
    singleton_expected:$singleton,
    singleton_codehash:$singleton_codehash, singleton_codesize:$singleton_codesize,
    proxy_codehash:$proxy_codehash, proxy_codesize:$proxy_codesize,
    domain_separator:$domain_separator}' > "$OUT/safe_state.json"

echo "=== safe_state.json ==="
cat "$OUT/safe_state.json" | jq .

# owners.json
echo "[" > "$OUT/owners.json"
FIRST=1
i=0
N=$(echo "$OWNERS_JSON" | jq 'length')
while [ $i -lt $N ]; do
  O=$(echo "$OWNERS_JSON" | jq -r ".[$i]")
  CODE_LATEST=$(cast code "$O" --block latest --rpc-url "$RPC")
  CODE_B=$(cast code "$O" --block "$B" --rpc-url "$RPC")
  BAL_O=$(cast balance "$O" --block "$B" --rpc-url "$RPC")
  NONCE_O=$(cast nonce "$O" --block "$B" --rpc-url "$RPC")
  [ $FIRST -eq 1 ] || echo "," >> "$OUT/owners.json"
  FIRST=0
  jq -n --arg addr "$O" --arg code_latest "$CODE_LATEST" --arg code_at_block "$CODE_B" \
        --arg balance_wei "$BAL_O" --arg nonce "$NONCE_O" --argjson block "$B" \
        '{address:$addr, is_contract_at_latest:($code_latest!="0x"), code_at_latest:$code_latest,
          eip7702_delegation:($code_latest|startswith("0xef0100")),
          code_at_snapshot_block:$code_at_block, code_at_snapshot_block_empty:($code_at_block=="0x"),
          balance_wei:$balance_wei, balance_metis:($balance_wei|tonumber/1e18), nonce:($nonce|tonumber), snapshot_block:$block} ' >> "$OUT/owners.json"
  i=$((i+1))
done
echo "]" >> "$OUT/owners.json"
echo "=== owners.json ==="
jq . "$OUT/owners.json"
echo "SNAPSHOT_BLOCK=$B"
