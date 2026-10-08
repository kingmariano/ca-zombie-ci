#!/usr/bin/env bash
# Read-only enumeration of Kinetic (Flare) comptrollers + markets.
# Usage: RPC=... bash enum.sh > markets-raw.txt
set -uo pipefail
RPC="${RPC:-https://flare-api.flare.network/ext/C/rpc}"
BLK=$(cast block-number --rpc-url "$RPC")
echo "# block $BLK"
echo "# rpc $RPC"

C1=0x15F69897E6aEBE0463401345543C26d1Fd994abB
C2=0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8

for C in $C1 $C2; do
  echo "=== COMPTROLLER $C ==="
  cast call "$C" "oracle()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/oracle: /'
  cast call "$C" "admin()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/admin: /'
  cast call "$C" "pendingAdmin()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/pendingAdmin: /'
  cast call "$C" "pauseGuardian()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/pauseGuardian: /'
  cast call "$C" "closeFactorMantissa()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/closeFactor: /'
  cast call "$C" "liquidationIncentiveMantissa()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/liqIncentive: /'
  # global pause flags (where present)
  for f in "mintGuardianPaused()(bool)" "borrowGuardianPaused()(bool)" "transferGuardianPaused()(bool)" "seizeGuardianPaused()(bool)" "redeemGuardianPaused()(bool)"; do
    v=$(cast call "$C" "$f" --rpc-url "$RPC" --block "$BLK" 2>/dev/null) && echo "${f%%(*}: $v"
  done
  MK=$(cast call "$C" "getAllMarkets()(address[])" --rpc-url "$RPC" --block "$BLK" | tr -d '[]' | tr ',' ' ')
  for M in $MK; do
    echo "--- market $M ---"
    cast call "$M" "symbol()(string)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/symbol: /'
    cast call "$M" "underlying()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/underlying: /'
    cast call "$M" "comptroller()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/comptroller_of_market: /'
    cast call "$M" "getCash()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/cash: /'
    cast call "$M" "totalSupply()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/totalSupply: /'
    cast call "$M" "totalBorrows()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/totalBorrows: /'
    cast call "$M" "totalReserves()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/totalReserves: /'
    cast call "$M" "exchangeRateStored()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/exchangeRateStored: /'
    cast call "$M" "exchangeRateCurrent()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/exchangeRateCurrent: /'
    cast call "$M" "reserveFactorMantissa()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/reserveFactor: /'
    cast call "$M" "initialExchangeRateMantissa()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/initialExchangeRate: /'
    cast call "$M" "accrualBlockNumber()(uint256)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/accrualBlockNumber: /'
    cast call "$M" "interestRateModel()(address)" --rpc-url "$RPC" --block "$BLK" | sed 's/^/irm: /'
    # comptroller market listing
    cast call "$C" "markets(address)(bool,uint256,bool)" "$M" --rpc-url "$RPC" --block "$BLK" | sed 's/^/markets(): /'
    for f in "mintGuardianPaused(address)(bool)" "borrowGuardianPaused(address)(bool)" "transferGuardianPaused(address)(bool)" "seizeGuardianPaused(address)(bool)" "redeemGuardianPaused(address)(bool)"; do
      v=$(cast call "$C" "$f" "$M" --rpc-url "$RPC" --block "$BLK" 2>/dev/null) && echo "${f%%(*}: $v"
    done
    # cToken-level pause if present
    for f in "mintPaused()(bool)" "borrowPaused()(bool)" "redeemPaused()(bool)"; do
      v=$(cast call "$M" "$f" --rpc-url "$RPC" --block "$BLK" 2>/dev/null) && echo "${f%%(*}: $v"
    done
  done
done
