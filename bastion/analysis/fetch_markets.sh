#!/usr/bin/env bash
# Read-only state dump of Bastion markets (Aurora) at a pinned block.
RPC=${AURORA_RPC:-https://mainnet.aurora.dev}
BLOCK=${1:-latest}
UNITROLLER=0x6De54724e128274520606f038591A00C5E94a1F6
C="cast call --rpc-url $RPC"
blkargs=""; [ "$BLOCK" != "latest" ] && blkargs="--block $BLOCK"
echo "{ \"block\": \"$(cast block-number --rpc-url $RPC)\", \"comptroller\": {"
echo "  \"oracle\": \"$($C $UNITROLLER 'oracle()(address)' $blkargs)\","
echo "  \"closeFactorMantissa\": \"$($C $UNITROLLER 'closeFactorMantissa()(uint256)' $blkargs)\","
echo "  \"liquidationIncentiveMantissa\": \"$($C $UNITROLLER 'liquidationIncentiveMantissa()(uint256)' $blkargs)\","
echo "  \"admin\": \"$($C $UNITROLLER 'admin()(address)' $blkargs)\","
echo "  \"pauseGuardian\": \"$($C $UNITROLLER 'pauseGuardian()(address)' $blkargs)\","
echo "  \"implementation\": \"$($C $UNITROLLER 'comptrollerImplementation()(address)' $blkargs)\""
echo "}, \"markets\": ["
first=1
for m in $($C $UNITROLLER 'getAllMarkets()(address[])' $blkargs | tr -d '[]' | tr ',' ' '); do
  [ $first -eq 1 ] || echo ","
  first=0
  echo " {"
  echo "  \"address\": \"$m\","
  echo "  \"symbol\": \"$($C $m 'symbol()(string)' $blkargs)\","
  echo "  \"name\": \"$($C $m 'name()(string)' $blkargs)\","
  echo "  \"underlying\": \"$($C $m 'underlying()(address)' $blkargs)\","
  echo "  \"exchangeRateStored\": \"$($C $m 'exchangeRateStored()(uint256)' $blkargs)\","
  echo "  \"totalSupply\": \"$($C $m 'totalSupply()(uint256)' $blkargs)\","
  echo "  \"totalBorrows\": \"$($C $m 'totalBorrows()(uint256)' $blkargs)\","
  echo "  \"totalReserves\": \"$($C $m 'totalReserves()(uint256)' $blkargs)\","
  echo "  \"cash\": \"$($C $m 'getCash()(uint256)' $blkargs)\","
  echo "  \"accrualBlockNumber\": \"$($C $m 'accrualBlockNumber()(uint256)' $blkargs)\","
  echo "  \"reserveFactorMantissa\": \"$($C $m 'reserveFactorMantissa()(uint256)' $blkargs)\","
  echo "  \"interestRateModel\": \"$($C $m 'interestRateModel()(address)' $blkargs)\","
  echo "  \"admin\": \"$($C $m 'admin()(address)' $blkargs)\","
  echo "  \"comptroller\": \"$($C $m 'comptroller()(address)' $blkargs)\","
  echo "  \"collateralFactorMantissa\": \"$($C $UNITROLLER 'markets(address)((bool,uint256,uint256))' $m $blkargs)\","
  echo "  \"mintGuardianPaused\": \"$($C $UNITROLLER 'mintGuardianPaused(address)(bool)' $m $blkargs)\","
  echo "  \"borrowGuardianPaused\": \"$($C $UNITROLLER 'borrowGuardianPaused(address)(bool)' $m $blkargs)\","
  echo "  \"transferGuardianPaused\": \"$($C $UNITROLLER 'transferGuardianPaused(address)(bool)' $m $blkargs)\","
  echo "  \"seizeGuardianPaused\": \"$($C $UNITROLLER 'seizeGuardianPaused(address)(bool)' $m $blkargs)\","
  echo "  \"borrowCap\": \"$($C $UNITROLLER 'borrowCaps(address)(uint256)' $m $blkargs)\","
  echo "  \"supplyCap\": \"$($C $UNITROLLER 'supplyCaps(address)(uint256)' $m $blkargs)\","
  echo "  \"compBorrowSpeed\": \"$($C $UNITROLLER 'compBorrowSpeeds(address)(uint256)' $m $blkargs 2>/dev/null || echo NA)\","
  echo "  \"_dummy\": 0"
  echo " }"
done
echo "]}"
