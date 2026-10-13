#!/usr/bin/env bash
# Cat in a Box — CI live-state dump. Writes to ci-out/ (uploaded as artifact).
# NEVER prints or stores RPC URLs / keys.
set -euo pipefail
RPC="${FORK_RPC_URL:-${RPC_URL:?}}"
mkdir -p ci-out

STETH=0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
BOXETH=0x7690202e2C2297bcD03664e31116d1dFfE7e3B73
BOXFEE=0xE4B91fAf8810F8895772E7cA065D4CB889120f94
CDP1=0x7f0a0c7149a46bf943ccd412da687144b49c6014
CDP11=0x6ffd098e92b606b2947b89a08911c00ca06890fa
PSM=0x24146D1B3339Cf76b455dC42e71Ea5Cdff4aE0d7
FEESPLIT=0x320c871b6f7721083604FfdD8070E64c1d3c5d7C
POOL005=0x287139599f1B5849f12Cf18244A74F595da9936D
POOLWST=0x703a177fcb4def281d180d3619a5edbae67ec7b5

BLK=$(cast block-number --rpc-url "$RPC")
OUT=ci-out/live-state.txt
{
  echo "block=$BLK"
  echo "cdp_v1_steth=$(cast call $STETH 'balanceOf(address)(uint256)' $CDP1 --rpc-url "$RPC" --block "$BLK")"
  echo "cdp_v11_steth=$(cast call $STETH 'balanceOf(address)(uint256)' $CDP11 --rpc-url "$RPC" --block "$BLK")"
  echo "psm_steth=$(cast call $STETH 'balanceOf(address)(uint256)' $PSM --rpc-url "$RPC" --block "$BLK")"
  echo "feesplit_steth=$(cast call $STETH 'balanceOf(address)(uint256)' $FEESPLIT --rpc-url "$RPC" --block "$BLK")"
  echo "boxfee_vault_boxeth=$(cast call $BOXETH 'balanceOf(address)(uint256)' $BOXFEE --rpc-url "$RPC" --block "$BLK")"
  echo "cdp_v1_totalDebt=$(cast call $CDP1 'totalDebt()(uint256)' --rpc-url "$RPC" --block "$BLK")"
  echo "cdp_v11_totalDebt=$(cast call $CDP11 'totalDebt()(uint256)' --rpc-url "$RPC" --block "$BLK")"
  echo "pool005_boxeth=$(cast call $BOXETH 'balanceOf(address)(uint256)' $POOL005 --rpc-url "$RPC" --block "$BLK")"
  echo "poolwst_boxeth=$(cast call $BOXETH 'balanceOf(address)(uint256)' $POOLWST --rpc-url "$RPC" --block "$BLK")"
  echo "pool005_sqrtPriceX96=$(cast call $POOL005 'slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)' --rpc-url "$RPC" --block "$BLK" | head -1)"
} > "$OUT" 2>&1
echo "wrote $OUT (block $BLK)"
