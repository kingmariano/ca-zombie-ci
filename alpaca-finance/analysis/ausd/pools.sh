#!/usr/bin/env bash
# Dump per-pool state for Alpaca AUSD on BSC. Usage: ./pools.sh [block]
set -u
if [ -z "${NODEREAL_API_KEY:-}" ] && [ -f /home/heisenberg/CA/.env ]; then
  set -a; . /home/heisenberg/CA/.env >/dev/null 2>&1; set +a
fi
RPC="https://bsc-mainnet.nodereal.io/v1/${NODEREAL_API_KEY}"
BLOCK="${1:-$(command cast block-number --rpc-url "$RPC")}"
cast() { command cast call "$@" --rpc-url "$RPC" --block "$BLOCK" 2>&1; }

CPC=0x06D280abee1073B83A01fE778B6145e850e87162
BK=0xD0AEcee1520B5F9925D952405F9A06Dcd8fd6e6C
POOLS=("ibBUSD" "ibUSDT" "ibWBNB" "BUSD-STABLE")
echo "=== pools @ block $BLOCK ==="
for name in "${POOLS[@]}"; do
  ID=$(command cast format-bytes32-string "$name")
  echo "--- pool $name ($ID)"
  echo "collateralPools: $(cast $CPC 'collateralPools(bytes32)(uint256,uint256,uint256,uint256,uint256,address,uint256,uint256,uint256,address,uint256,uint256,uint256,address)' $ID)"
  echo "priceWithSafetyMargin: $(cast $CPC 'getPriceWithSafetyMargin(bytes32)(uint256)' $ID)"
  echo "totalDebtShare:        $(cast $CPC 'getTotalDebtShare(bytes32)(uint256)' $ID)"
  echo "debtAccumulatedRate:   $(cast $CPC 'getDebtAccumulatedRate(bytes32)(uint256)' $ID)"
  echo "debtCeiling:           $(cast $CPC 'getDebtCeiling(bytes32)(uint256)' $ID)"
  echo "debtFloor:             $(cast $CPC 'getDebtFloor(bytes32)(uint256)' $ID)"
  echo "priceFeed:             $(cast $CPC 'getPriceFeed(bytes32)(address)' $ID)"
  echo "liquidationRatio:      $(cast $CPC 'getLiquidationRatio(bytes32)(uint256)' $ID)"
  echo "stabilityFeeRate:      $(cast $CPC 'getStabilityFeeRate(bytes32)(uint256)' $ID)"
  echo "lastAccumulationTime:  $(cast $CPC 'getLastAccumulationTime(bytes32)(uint256)' $ID)"
  echo "adapter:               $(cast $CPC 'getAdapter(bytes32)(address)' $ID)"
  echo "closeFactorBps:        $(cast $CPC 'getCloseFactorBps(bytes32)(uint256)' $ID)"
  echo "liquidatorIncentiveBps:$(cast $CPC 'getLiquidatorIncentiveBps(bytes32)(uint256)' $ID)"
  echo "treasuryFeesBps:       $(cast $CPC 'getTreasuryFeesBps(bytes32)(uint256)' $ID)"
  echo "strategy:              $(cast $CPC 'getStrategy(bytes32)(address)' $ID)"
done
