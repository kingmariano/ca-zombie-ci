#!/usr/bin/env bash
# Enumerate all ApeSwap Lending markets on BSC (read-only, latest block).
source /home/heisenberg/CA/apeswap-lending/analysis/rpc.sh
CMP=0xad48b2c9dc6709a560018c678e918253a65df86e
REG=0xAE933Da5860559080F47e594504CE5445D86f78a
OUT=/home/heisenberg/CA/apeswap-lending/analysis/markets.tsv
blk=$(B)
echo "block=$blk"
: > "$OUT"
printf 'addr\tsymbol\tunderlying\tunderlying_decimals\tcash\ttotalSupply\ttotalBorrows\ttotalReserves\texchangeRateStored\treserveFactor\taccrualBlock\tmarket_tuple\tborrowCap\tmintPaused\tborrowPaused\tpriceLen\tpriceReg\n' >> "$OUT"
MARKETS=$(C $CMP 'getAllMarkets()(address[])' | tr -d '[]' | tr ',' ' ')
for m in $MARKETS; do
  sym=$(C $m 'symbol()(string)' 2>/dev/null | tr -d '"' | tr -d '\n')
  und=$(C $m 'underlying()(address)')
  dec=$(cast call --rpc-url "$BSC_RPC" "$und" 'decimals()(uint8)' 2>/dev/null || echo NA)
  cash=$(C $m 'cash()(uint256)')
  ts=$(C $m 'totalSupply()(uint256)')
  tb=$(C $m 'totalBorrows()(uint256)')
  tr=$(C $m 'totalReserves()(uint256)')
  er=$(C $m 'exchangeRateStored()(uint256)')
  rf=$(C $m 'reserveFactorMantissa()(uint256)')
  ab=$(C $m 'accrualBlockNumber()(uint256)')
  mkt=$(C $CMP 'markets(address)(bool,uint256,uint256,uint256,uint256,uint256)' $m | tr '\n' ' ' | tr -s ' ')
  bc=$(C $CMP 'borrowCaps(address)(uint256)' $m)
  mp=$(C $CMP 'mintGuardianPaused(address)(bool)' $m)
  bp=$(C $CMP 'borrowGuardianPaused(address)(bool)' $m)
  pl=$(C $CMP 'getUnderlyingPriceInLen(address)(uint256)' "$und" 2>/dev/null || echo ERR)
  pr=$(C $REG 'getPriceForAsset(address)(uint256)' "$und" 2>/dev/null || echo ERR)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$m" "$sym" "$und" "$dec" "$cash" "$ts" "$tb" "$tr" "$er" "$rf" "$ab" "$mkt" "$bc" "$mp" "$bp" "$pl" "$pr" >> "$OUT"
  printf 'done %s %s cash=%s supply=%s borrows=%s\n' "$m" "$sym" "$cash" "$ts" "$tb"
done
echo "block_after=$(B)"
echo "written $OUT"
