#!/usr/bin/env bash
# Live read-only state snapshot for the 4 IntentX diamonds. Records block numbers.
set -u
OUT=/home/heisenberg/CA/intentx/analysis/core/live
mkdir -p "$OUT"
declare -A RPCS=( [base]="https://base-rpc.publicnode.com" [arb]="https://arb1.arbitrum.io/rpc" [mantle]="https://rpc.mantle.xyz" [blast]="https://blast-rpc.publicnode.com" )
declare -A DIAMONDS=( [base]="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43" [arb]="0x8F06459f184553e5d04F07F868720BDaCAB39395" [mantle]="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5" [blast]="0x3d17f073cCb9c3764F105550B0BCF9550477D266" )
declare -A COLL=( [base]="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" [arb]="0xaf88d065e77c8cC2239327C5EDb3A432268e5831" [mantle]="0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34" [blast]="0x4300000000000000000000000000000000000003" )

CALLS=(
 "owner()"
 "getCollateral()"
 "getMuonConfig()"
 "getMuonIds()"
 "pauseState()"
 "balanceLimitPerUser()"
 "liquidatorShare()"
 "liquidationTimeout()"
 "coolDownsOfMA()"
 "pendingQuotesValidLength()"
 "getInvalidBridgedAmountsPool()"
 "isCrossPartyBModeActivated()"
 "deallocateCooldown()"
)

for chain in base arb mantle blast; do
  rpc=${RPCS[$chain]}; d=${DIAMONDS[$chain]}; c=${COLL[$chain]}
  blk=$(cast block-number --rpc-url "$rpc")
  {
    echo "# chain=$chain diamond=$d collateral=$c block=$blk"
    for call in "${CALLS[@]}"; do
      res=$(cast call "$d" "$call" --rpc-url "$rpc" 2>&1 | tr '\n' ' ')
      echo "$call => $res"
    done
    # collateral balance of diamond
    res=$(cast call "$c" "balanceOf(address)(uint256)" "$d" --rpc-url "$rpc" 2>&1 | tr '\n' ' ')
    echo "collateral.balanceOf(diamond) => $res"
  } > "$OUT/${chain}_state.txt" 2>&1
  echo "done $chain block=$blk"
done

# role hashes
{
  for r in DEFAULT_ADMIN_ROLE LIQUIDATOR_ROLE PARTYB_LIQUIDATOR_ROLE DISPUTE_ROLE CLEARING_HOUSE_ROLE BALANCE_SETTLER_ROLE SIGNER_ADMIN_ROLE MUON_SETTER_ROLE PROTOCOL_CONFIG_ROLE WITHDRAW_FORCE_CANCEL_ROLE WITHDRAW_SPEED_UP_ROLE SUSPENDER_ROLE PARTY_B_MANAGER_ROLE PAUSER_ROLE UNPAUSER_ROLE COOLDOWN_ADMIN_ROLE MIGRATION_ROLE FEE_ADMIN_ROLE INSTANT_LAYER_ROLE; do
    echo "$r $(cast keccak "$r")"
  done
} > "$OUT/role_hashes.txt"
echo "role hashes written"
