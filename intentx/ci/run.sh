#!/usr/bin/env bash
# Read-only live-state dump for the IntentX finding. No transactions are sent.
# Results are written to ci-out/ (uploaded as CI artifacts).
set -u
mkdir -p ci-out
OUT=ci-out/state.txt
JSON=ci-out/state.json
: > "$OUT"
echo "{" > "$JSON"
first=1
add() { # key value
  if [ $first -eq 0 ]; then echo "," >> "$JSON"; fi
  first=0
  printf '  "%s": %s' "$1" "$2" >> "$JSON"
}

RPC_BASE="${BASE_RPC_URL:-https://base-rpc.publicnode.com}"
RPC_ARB="${ARB_RPC_URL:-https://arb1.arbitrum.io/rpc}"
RPC_MANTLE="${MANTLE_RPC_URL:-https://rpc.mantle.xyz}"
RPC_BLAST="${BLAST_RPC_URL:-https://blast-rpc.publicnode.com}"

BASE_DIAMOND=0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43
BASE_USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
ARB_DIAMOND=0x8F06459f184553e5d04F07F868720BDaCAB39395
ARB_USDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
MANTLE_DIAMOND=0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5
MANTLE_USDE=0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34
BLAST_DIAMOND=0x3d17f073cCb9c3764F105550B0BCF9550477D266
BLAST_USDB=0x4300000000000000000000000000000000000003

ARB_PB_VULN=0x0b5b3f9b727656a254ec1203d8b2a86b4540f5f5
ARB_PB_VULN_IMPL=0x556f255e0e671c760e21e01cd7c3a4fb4722ed3a
ARB_PB_FIXED_IMPL=0x2554727881c5fb22965c6fcb7c6042b367845362
BASE_INSTANT_LAYER=0x0825435285ac0e5c02c7a7c443f631f3e07fe375
ARB_INSTANT_LAYER=0x4a6a866e62b38eedfd4d99599f7e2baa35336d1c
BASE_VAULT=0x7785fE35F6510D111063579AA14F7D28aD84512A
BASE_LP=0xB6d340Af68279326402139C30934317929535D32

log() { echo "$@" | tee -a "$OUT"; }

log "== IntentX live state (read-only) =="
log "base block:   $(cast block-number --rpc-url "$RPC_BASE" 2>/dev/null)"
log "arb block:    $(cast block-number --rpc-url "$RPC_ARB" 2>/dev/null)"
log "mantle block: $(cast block-number --rpc-url "$RPC_MANTLE" 2>/dev/null)"
log "blast block:  $(cast block-number --rpc-url "$RPC_BLAST" 2>/dev/null)"

BASE_BAL=$(cast call --rpc-url "$RPC_BASE" "$BASE_USDC" "balanceOf(address)(uint256)" "$BASE_DIAMOND" 2>/dev/null | awk '{print $1}')
ARB_BAL=$(cast call --rpc-url "$RPC_ARB" "$ARB_USDC" "balanceOf(address)(uint256)" "$ARB_DIAMOND" 2>/dev/null | awk '{print $1}')
MANTLE_BAL=$(cast call --rpc-url "$RPC_MANTLE" "$MANTLE_USDE" "balanceOf(address)(uint256)" "$MANTLE_DIAMOND" 2>/dev/null | awk '{print $1}')
BLAST_BAL=$(cast call --rpc-url "$RPC_BLAST" "$BLAST_USDB" "balanceOf(address)(uint256)" "$BLAST_DIAMOND" 2>/dev/null | awk '{print $1}')
log "base diamond USDC (6dp):    $BASE_BAL"
log "arb diamond USDC (6dp):     $ARB_BAL"
log "mantle diamond USDe (18dp): $MANTLE_BAL"
log "blast diamond USDB (18dp):  $BLAST_BAL"

BASE_FLAG=$(cast call --rpc-url "$RPC_BASE" "$BASE_DIAMOND" "isCallFromInstantLayer()(bool)" 2>/dev/null)
ARB_FLAG=$(cast call --rpc-url "$RPC_ARB" "$ARB_DIAMOND" "isCallFromInstantLayer()(bool)" 2>/dev/null)
MANTLE_FLAG=$(cast call --rpc-url "$RPC_MANTLE" "$MANTLE_DIAMOND" "isCallFromInstantLayer()(bool)" 2>/dev/null)
BLAST_FLAG=$(cast call --rpc-url "$RPC_BLAST" "$BLAST_DIAMOND" "isCallFromInstantLayer()(bool)" 2>/dev/null)
log "base instant flag:   $BASE_FLAG"
log "arb instant flag:    $ARB_FLAG"
log "mantle instant flag: $MANTLE_FLAG"
log "blast instant flag:  $BLAST_FLAG"

VULN_SEL=$(cast sig "isCallFromInstantLayer()" | cut -c3-)
ROLE_HASH=$(cast keccak "INSTANT_LAYER_ROLE" | cut -c3-)
log "partyB fingerprint: vulnerable selector 0x$VULN_SEL | fixed role-hash 0x$ROLE_HASH"

impl_fp() { # impl -> "vuln_sel=... role_hash=..."
  local code; code=$(cast code --rpc-url "$RPC_ARB" "$1" 2>/dev/null)
  local vs=no rh=no
  echo "$code" | grep -qi "$VULN_SEL" && vs=yes
  echo "$code" | grep -qi "$ROLE_HASH" && rh=yes
  echo "vuln_sel=$vs role_hash=$rh"
}
log "arb vuln  impl $ARB_PB_VULN_IMPL:  $(impl_fp $ARB_PB_VULN_IMPL)"
log "arb fixed impl $ARB_PB_FIXED_IMPL: $(impl_fp $ARB_PB_FIXED_IMPL)"

ARB_PB_TXCOUNT=$(cast nonce --rpc-url "$RPC_ARB" "$ARB_PB_VULN" 2>/dev/null)
log "arb vuln partyB contract-nonce: $ARB_PB_TXCOUNT"

BASE_TPL=$(cast call --rpc-url "$RPC_BASE" "$BASE_INSTANT_LAYER" "getNextTemplateId()(uint256)" 2>/dev/null | awk '{print $1}')
log "base instant layer nextTemplateId: $BASE_TPL"
ARB_IL_NONCE=$(cast nonce --rpc-url "$RPC_ARB" "$ARB_INSTANT_LAYER" 2>/dev/null)
log "arb instant layer contract-nonce: $ARB_IL_NONCE"

VAULT_BAL=$(cast call --rpc-url "$RPC_BASE" "$BASE_USDC" "balanceOf(address)(uint256)" "$BASE_VAULT" 2>/dev/null | awk '{print $1}')
LP_SUPPLY=$(cast call --rpc-url "$RPC_BASE" "$BASE_LP" "totalSupply()(uint256)" 2>/dev/null | awk '{print $1}')
log "base solver vault USDC: $VAULT_BAL ; LP totalSupply: $LP_SUPPLY"

add "base_block" "$(cast block-number --rpc-url "$RPC_BASE" 2>/dev/null || echo 0)"
add "arb_block" "$(cast block-number --rpc-url "$RPC_ARB" 2>/dev/null || echo 0)"
add "mantle_block" "$(cast block-number --rpc-url "$RPC_MANTLE" 2>/dev/null || echo 0)"
add "blast_block" "$(cast block-number --rpc-url "$RPC_BLAST" 2>/dev/null || echo 0)"
add "base_diamond_usdc" "${BASE_BAL:-0}"
add "arb_diamond_usdc" "${ARB_BAL:-0}"
add "mantle_diamond_usde" "${MANTLE_BAL:-0}"
add "blast_diamond_usdb" "${BLAST_BAL:-0}"
add "base_instant_flag" "${BASE_FLAG:-false}"
add "arb_instant_flag" "${ARB_FLAG:-false}"
add "mantle_instant_flag" "${MANTLE_FLAG:-false}"
add "blast_instant_flag" "${BLAST_FLAG:-false}"
add "arb_vuln_partyB_txcount" "${ARB_PB_TXCOUNT:-0}"
add "base_instant_layer_next_template" "${BASE_TPL:-0}"
add "arb_instant_layer_txcount" "${ARB_IL_NONCE:-0}"
add "base_vault_usdc" "${VAULT_BAL:-0}"
add "base_lp_supply" "${LP_SUPPLY:-0}"
echo "" >> "$JSON"
echo "}" >> "$JSON"

log "== done =="
cat "$OUT"
