#!/usr/bin/env bash
# Read-only IronController market dump (Polygon) via public RPC. No keys.
P=https://polygon-bor-rpc.publicnode.com
CTRL=0xF20fcd005AFDd3AD48C85d0222210fe168DDd10c
OUT=analysis/lending-polygon.txt
: > $OUT
echo "block: $(cast block-number --rpc-url $P)" >> $OUT
MARKETS=$(cast call $CTRL "getAllMarkets()(address[])" --rpc-url $P | tr -d '[]' | tr ',' '\n')
for m in $MARKETS; do
  {
    echo "=== market $m"
    echo -n "symbol: ";    cast call $m "symbol()(string)" --rpc-url $P 2>&1
    echo -n "underlying: "; cast call $m "underlying()(address)" --rpc-url $P 2>&1
    echo -n "getCash: ";   cast call $m "getCash()(uint256)" --rpc-url $P 2>&1
    echo -n "totalBorrows: "; cast call $m "totalBorrows()(uint256)" --rpc-url $P 2>&1
    echo -n "totalSupply: "; cast call $m "totalSupply()(uint256)" --rpc-url $P 2>&1
    echo -n "totalReserves: "; cast call $m "totalReserves()(uint256)" --rpc-url $P 2>&1
    echo -n "exchangeRateStored: "; cast call $m "exchangeRateStored()(uint256)" --rpc-url $P 2>&1
    echo -n "accrualBlockNumber: "; cast call $m "accrualBlockNumber()(uint256)" --rpc-url $P 2>&1
    echo -n "admin: "; cast call $m "admin()(address)" --rpc-url $P 2>&1
    echo -n "comptroller: "; cast call $m "comptroller()(address)" --rpc-url $P 2>&1
    echo -n "isCToken: "; cast call $m "isCToken()(bool)" --rpc-url $P 2>&1
  } >> $OUT
done
cat $OUT
