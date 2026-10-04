#!/usr/bin/env bash
# Read-only state dump of Rho Markets (Scroll). Uses publicnode; parallel.
set -u
R=https://scroll-rpc.publicnode.com
COMP=0x8a67AB98A291d1AEA2E1eB0a79ae4ab7f2D76041
ORACLE=0x653C2D3A1E4Ac5330De3c9927bb9BDC51008f9d5
BLOCK=$(cast block-number --rpc-url $R)
echo "block=$BLOCK"
mkdir -p dump
markets=(
0x639355f34Ca9935E0004e30bD77b9cE2ADA0E692
0x855CEA8626Fa7b42c13e7A688b179bf61e6c1e81
0xAE1846110F72f2DaaBC75B7cEEe96558289EDfc5
0xAD3d07d431B85B525D81372802504Fa18DBd554c
0xe4FC4C444efFB5ECa80274c021f652980794Eae6
0x8966993138b95b48142f6ecB590427eb7e18a719
0x8698fB1093b6DBC345e2aAFEb853C602A3582548
0x00B49129Af3be28D0Cdb1e60B155B234d0E19190
0x65a5dBEf0D1Bff772822E4652Aed2829718DC43F
0x52Fef2B9040BA81e40421660335655D70Fe8Cf03
0x5fF1926507f6e71bFbd5f9897fBaeF021E2F77CA
0x76DC94562c89D2820E88D1274d4Bb32Cee306d4C
0x1D73ead2BBEa318344fccD7142F70488BAb08F44
0xFE707359517f0d5AD0187a237974D3110A734016
0x7AE3c19De353ce163Fe81AE3ebFC90709d3868BE
0xC34721FE52284FAB7AEC852A48CB45108F8b4aCa
)
call() { cast call "$1" "$2" --rpc-url $R 2>/dev/null | head -1 | tr -d '\n' | sed 's/^"//; s/"$//'; }
export -f call
export R COMP ORACLE
one() {
  m=$1; f="dump/${m}.json"
  sym=$(call $m "symbol()(string)")
  und=$(call $m "underlying()(address)")
  ts=$(call $m "totalSupply()(uint256)")
  tb=$(call $m "totalBorrows()(uint256)")
  tr=$(call $m "totalReserves()(uint256)")
  cash=$(call $m "getCash()(uint256)")
  er=$(call $m "exchangeRateStored()(uint256)")
  mk=$(cast call $COMP "markets(address)(bool,uint256)" $m --rpc-url $R 2>/dev/null | tr '\n' ' ')
  mp=$(call $COMP "mintGuardianPaused(address)(bool)" $m)
  bp=$(call $COMP "borrowGuardianPaused(address)(bool)" $m)
  rp=$(call $COMP "redeemGuardianPaused(address)(bool)" $m)
  bpcap=$(call $COMP "borrowCaps(address)(uint256)" $m)
  price=$(call $ORACLE "getUnderlyingPrice(address)(uint256)" $m)
  echo "{\"market\":\"$m\",\"symbol\":\"$sym\",\"underlying\":\"$und\",\"totalSupply\":\"$ts\",\"totalBorrows\":\"$tb\",\"totalReserves\":\"$tr\",\"cash\":\"$cash\",\"exchangeRateStored\":\"$er\",\"markets\":\"$mk\",\"mintPaused\":\"$mp\",\"borrowPaused\":\"$bp\",\"redeemPaused\":\"$rp\",\"borrowCap\":\"$bpcap\",\"oraclePrice\":\"$price\"}" > "$f"
  echo "done $m"
}
export -f one
printf '%s\n' "${markets[@]}" | xargs -P 6 -I{} bash -c 'one {}'
echo "== comptroller globals =="
{
echo "pauseGuardian=$(call $COMP "pauseGuardian()(address)")"
echo "admin=$(call $COMP "admin()(address)")"
echo "closeFactorMantissa=$(call $COMP "closeFactorMantissa()(uint256)")"
echo "liquidationIncentiveMantissa=$(call $COMP "liquidationIncentiveMantissa()(uint256)")"
echo "transferGuardianPaused=$(call $COMP "transferGuardianPaused()(bool)")"
echo "seizeGuardianPaused=$(call $COMP "seizeGuardianPaused()(bool)")"
echo "borrowCapGuardian=$(call $COMP "borrowCapGuardian()(address)")"
echo "supplyCapGuardian=$(call $COMP "supplyCapGuardian()(address)")"
echo "oracle=$(call $COMP "oracle()(address)")"
} | tee dump/globals.txt
