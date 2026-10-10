#!/usr/bin/env bash
# H2-05 (eos-misc) CI: re-verify CHATEAU (Plasma) + Vena (Fluent) live state (read-only, public RPCs).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
OUT=ci-out/plasma-fluent-verify.json
FAIL=0

# cast call prints a human annotation after the value; keep the raw value only
raw() { awk '{print $1}'; }
check() { # name expected actual
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS $name :: $actual"
  else
    echo "FAIL $name :: expected=$expected actual=$actual"
    FAIL=1
  fi
}

PLASMA_RPC="https://rpc.plasma.to"
FLUENT_RPC="https://rpc.fluent.xyz"

# --- CHATEAU chUSD (Plasma 9745) at block 34,691,115 ---
P_BLOCK=34691115
P_CHAIN=$(cast chain-id --rpc-url "$PLASMA_RPC")
check "plasma.chain_id" "9745" "$P_CHAIN"
P_SUPPLY=$(cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "totalSupply()(uint256)" --rpc-url "$PLASMA_RPC" --block $P_BLOCK | raw)
check "chateau.chusd_totalSupply" "1024692236150956000000000" "$P_SUPPLY"
P_COLL=$(cast call 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb "balanceOf(address)(uint256)" 0xEA6709C29d4D4B5162d8C55D0c28C5CED6cd7296 --rpc-url "$PLASMA_RPC" --block $P_BLOCK | raw)
check "chateau.collateral_usdt0" "77307860" "$P_COLL"
P_MINTER=$(cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "minter()(address)" --rpc-url "$PLASMA_RPC" --block $P_BLOCK | raw)
check "chateau.minter" "0xEA6709C29d4D4B5162d8C55D0c28C5CED6cd7296" "$P_MINTER"

# --- Vena (Fluent 25363) at block 17,863,118 ---
F_BLOCK=17863118
F_CHAIN=$(cast chain-id --rpc-url "$FLUENT_RPC")
check "fluent.chain_id" "25363" "$F_CHAIN"
V_USDNR=$(cast call 0xD48e565561416dE59DA1050ED70b8d75e8eF28f9 "balanceOf(address)(uint256)" 0x3Ebf3cfcCDCd96edC1C506907C17eec2BdC31008 --rpc-url "$FLUENT_RPC" --block $F_BLOCK | raw)
check "vena.aUSDnr_underlying" "545341402995" "$V_USDNR"
V_SUDNR=$(cast call 0xFa9b3B45587f9fcdE14759121C3868C2733DCbf4 "balanceOf(address)(uint256)" 0x3161bF68Bc6e582D682458F8766b219E8e2821Ed --rpc-url "$FLUENT_RPC" --block $F_BLOCK | raw)
check "vena.asUSDnr_underlying" "8457557196359" "$V_SUDNR"

{
  echo "{"
  echo "  \"plasma_block\": $P_BLOCK,"
  echo "  \"fluent_block\": $F_BLOCK,"
  echo "  \"chateau_chusd_supply_raw\": \"$P_SUPPLY\","
  echo "  \"chateau_collateral_usdt0_raw\": \"$P_COLL\","
  echo "  \"vena_aUSDnr_underlying_raw\": \"$V_USDNR\","
  echo "  \"vena_asUSDnr_underlying_raw\": \"$V_SUDNR\","
  echo "  \"checks_failed\": $FAIL"
  echo "}"
} > "$OUT"

if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "plasma/fluent verification done"
