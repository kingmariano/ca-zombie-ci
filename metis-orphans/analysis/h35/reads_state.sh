#!/usr/bin/env bash
# H-35 state reads — READ ONLY. Pins an explicit block for all reads.
set -uo pipefail
RPC='https://andromeda.metis.io/?owner=1088'
SAFE=0xdd7c49D1bA862b1285710A30E20C2438b13AE532
SING=0xfb1bffc9d739b8d520daf37df666da4c687191ea
B=23238718
OUT=/home/heisenberg/CA/metis-orphans/analysis/h35
mkdir -p "$OUT/raw"

log(){ echo "[$1] $2"; }

echo "### PINNED BLOCK $B"
HASH=$(cast block "$B" --field hash --rpc-url "$RPC")
echo "block_hash=$HASH"
echo "$B" > "$OUT/raw/block_number.txt"
echo "$HASH" > "$OUT/raw/block_hash.txt"

echo "### slot0 (masterCopy)"
cast storage "$SAFE" 0 --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/slot0_masterCopy.txt"

echo "### threshold()"
cast call "$SAFE" 'threshold()(uint256)' --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/threshold.txt"

echo "### nonce()"
cast call "$SAFE" 'nonce()(uint256)' --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/nonce.txt"

echo "### getOwners()"
cast call "$SAFE" 'getOwners()(address[])' --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/owners.txt"

echo "### VERSION() via proxy"
cast call "$SAFE" 'VERSION()(string)' --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/version_proxy.txt"

echo "### VERSION() via singleton direct"
cast call "$SING" 'VERSION()(string)' --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/version_singleton.txt"

echo "### getModulesPaginated(sentinel,100) via proxy"
cast call "$SAFE" 'getModulesPaginated(address,uint256)(address[],address)' 0x0000000000000000000000000000000000000001 100 --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/modules_paginated_proxy.txt"

echo "### getModules() via proxy (may not exist in v1.3.0)"
cast call "$SAFE" 'getModules()(address[])' --block "$B" --rpc-url "$RPC" 2>&1 | tee "$OUT/raw/modules_legacy_proxy.txt"

echo "### getGuard() via proxy"
cast call "$SAFE" 'getGuard()(address)' --block "$B" --rpc-url "$RPC" 2>&1 | tee "$OUT/raw/guard_proxy.txt"

echo "### getGuard() via singleton direct"
cast call "$SING" 'getGuard()(address)' --block "$B" --rpc-url "$RPC" 2>&1 | tee "$OUT/raw/guard_singleton.txt"

echo "### selector of getGuard()"
cast sig 'getGuard()' | tee "$OUT/raw/selector_getGuard.txt"

echo "### selector of getModules()"
cast sig 'getModules()' | tee "$OUT/raw/selector_getModules.txt"

echo "### singleton code (file)"
cast code "$SING" --block "$B" --rpc-url "$RPC" > "$OUT/raw/singleton_code.hex"
echo "singleton code bytes: $(cast codesize "$SING" --block "$B" --rpc-url "$RPC")"
cast codehash "$SING" --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/singleton_codehash.txt"

echo "### proxy code (file)"
cast code "$SAFE" --block "$B" --rpc-url "$RPC" > "$OUT/raw/proxy_code.hex"
echo "proxy code bytes: $(cast codesize "$SAFE" --block "$B" --rpc-url "$RPC")"
cast codehash "$SAFE" --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/proxy_codehash.txt"

echo "### fallback_manager.handler.address slot"
FSLOT=$(cast keccak 'fallback_manager.handler.address')
echo "fslot=$FSLOT"
cast storage "$SAFE" "$FSLOT" --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/fallback_handler_storage.txt"

echo "### guard_manager.guard.address slot"
GSLOT=$(cast keccak 'guard_manager.guard.address')
echo "gslot=$GSLOT"
cast storage "$SAFE" "$GSLOT" --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/guard_storage.txt"

echo "### raw storage slots 1..8 (cross-check layout)"
for S in 1 2 3 4 5 6 7 8; do
  printf 'slot%s=' "$S"
  cast storage "$SAFE" "$S" --block "$B" --rpc-url "$RPC"
done | tee "$OUT/raw/storage_slots_1_8.txt"

echo "### owners array length slot keccak256(2)"
cast storage "$SAFE" "$(cast keccak 0x0000000000000000000000000000000000000000000000000000000000000002)" --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/owners_array_len.txt"

echo "### domainSeparator"
cast call "$SAFE" 'domainSeparator()(bytes32)' --block "$B" --rpc-url "$RPC" | tee "$OUT/raw/domain_separator.txt"

echo "### getThreshold() [expect revert on 1.3.0]"
cast call "$SAFE" 'getThreshold()(uint256)' --block "$B" --rpc-url "$RPC" 2>&1 | tee "$OUT/raw/getThreshold_revert.txt"

echo "### singleton self-call supportedInterfaces check via ERC165"
cast call "$SING" 'supportsInterface(bytes4)(bool)' 0x4e2312e0 --block "$B" --rpc-url "$RPC" 2>&1 | tee "$OUT/raw/singleton_supportsInterface.txt"

echo "DONE"
