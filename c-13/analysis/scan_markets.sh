#!/usr/bin/env bash
# Read-only market enumeration for Capyfi Unitroller (Ethereum)
R="${1:-https://ethereum-rpc.publicnode.com}"
C=0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA
BLK=$(cast block-number --rpc-url $R)
echo "block=$BLK"
MARKETS=$(cast call $C "getAllMarkets()(address[])" --rpc-url $R | tr -d '[],')
echo "markets: $MARKETS"
echo "symbol|market|underlying|uSym|cash|totalSupply|totalBorrows|totalReserves|exRateStored|exRateCurrent|cf|price|mintPaused|borrowPaused|transferPaused|seizePaused|irModel"
for m in $MARKETS; do
  sym=$(cast call $m "symbol()(string)" --rpc-url $R 2>/dev/null)
  u=$(cast call $m "underlying()(address)" --rpc-url $R 2>/dev/null)
  usym=""
  if [ -n "$u" ] && [ "$u" != "0x0000000000000000000000000000000000000000" ]; then
    usym=$(cast call $u "symbol()(string)" --rpc-url $R 2>/dev/null)
    cash=$(cast call $u "balanceOf(address)(uint256)" $m --rpc-url $R 2>/dev/null)
  else
    cash=$(cast balance $m --rpc-url $R 2>/dev/null)
    usym="ETH"
  fi
  ts=$(cast call $m "totalSupply()(uint256)" --rpc-url $R 2>/dev/null)
  tb=$(cast call $m "totalBorrows()(uint256)" --rpc-url $R 2>/dev/null)
  tr=$(cast call $m "totalReserves()(uint256)" --rpc-url $R 2>/dev/null)
  ers=$(cast call $m "exchangeRateStored()(uint256)" --rpc-url $R 2>/dev/null)
  erc=$(cast call $m "exchangeRateCurrent()(uint256)" --rpc-url $R 2>/dev/null)
  cf=$(cast call $C "markets(address)(uint256,bool,uint256)" $m --rpc-url $R 2>/dev/null | tr -d '[]' | cut -d' ' -f1)
  price=$(cast call $C "getUnderlyingPrice(address)(uint256)" $m --rpc-url $R 2>/dev/null)
  mp=$(cast call $C "mintGuardianPaused(address)(bool)" $m --rpc-url $R 2>/dev/null)
  bp=$(cast call $C "borrowGuardianPaused(address)(bool)" $m --rpc-url $R 2>/dev/null)
  tp=$(cast call $C "transferGuardianPaused()(bool)" --rpc-url $R 2>/dev/null)
  sp=$(cast call $C "seizeGuardianPaused()(bool)" --rpc-url $R 2>/dev/null)
  irm=$(cast call $m "interestRateModel()(address)" --rpc-url $R 2>/dev/null)
  echo "$sym|$m|$u|$usym|$cash|$ts|$tb|$tr|$ers|$erc|$cf|$price|$mp|$bp|$tp|$sp|$irm"
done
