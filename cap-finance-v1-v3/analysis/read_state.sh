#!/usr/bin/env bash
# Read live Cap Finance state on Arbitrum (read-only). No secrets in output.
set -u
export PATH="$PATH:$HOME/.foundry/bin"
RPC="${ARB_RPC:-https://arb1.arbitrum.io/rpc}"
OUT="$(dirname "$0")/state/state-live.txt"
mkdir -p "$(dirname "$OUT")"

call() { # addr sig
  local a="$1"; shift
  printf "%-46s %-42s " "$a" "$*"
  cast call "$a" "$@" --rpc-url "$RPC" 2>&1 | head -2 | tr '\n' ' '
  echo
}

BLK=$(cast block-number --rpc-url "$RPC")
echo "block=$BLK" | tee "$OUT"

{
echo "== block $BLK"

echo; echo "-- Treasury 0x1058AFe6 (v1)"
T=0x1058AFe66BB5b79C295CCCE51016586949Bc4e8d
call $T "owner()(address)"
call $T "trading()(address)"
call $T "oracle()(address)"
call $T "fundOracle()(address)"
call $T "vaultBalance()(uint256)"
call $T "vaultThreshold()(uint256)"
call $T "uniswapRouter()(address)"
call $T "WETH9()(address)"

echo; echo "-- Trading v1 0xA55Eee92"
T=0xA55Eee92a46A50A4C65908F28A0BE966D3e71633
call $T "owner()(address)"
call $T "treasury()(address)"
call $T "oracle()(address)"
call $T "liquidationThreshold()(uint256)"
call $T "minMargin()(uint256)"
call $T "maxSettlementTime()(uint256)"
call $T "nextPositionId()(uint256)"
call $T "nextCloseOrderId()(uint256)"

echo; echo "-- Trading v2a 0xCAEc6505"
T=0xCAEc650502F15c1a6bFf1C2288fC8F819776B2eC
call $T "owner()(address)"
call $T "treasury()(address)"
call $T "oracle()(address)"
call $T "router()(address)"
call $T "nextPositionId()(uint256)"
call $T "nextCloseOrderId()(uint256)"

echo; echo "-- Trading v2b 0xbEd32937"
T=0xbEd32937D8A5D1421241F52809908f1a17D75bDb
call $T "owner()(address)"
call $T "treasury()(address)"
call $T "oracle()(address)"
call $T "router()(address)"
call $T "nextPositionId()(uint256)"
call $T "nextCloseOrderId()(uint256)"

echo; echo "-- Trading v3 0x9BC357bc"
T=0x9BC357bc5b312AaCD41a84F3C687F031B8786853
call $T "owner()(address)"
call $T "nextPositionId()(uint256)"
call $T "nextStakeId()(uint256)"
call $T "MIN_MARGIN()(uint256)"
call $T "protocolFee()(uint256)"

echo; echo "-- Pool ETH 0xE0cCd451"
T=0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e
call $T "owner()(address)"
call $T "router()(address)"
call $T "trading()(address)"
call $T "currency()(address)"
call $T "rewards()(address)"
call $T "totalSupply()(uint256)"
call $T "openInterest()(uint256)"
call $T "withdrawFee()(uint256)"
call $T "minDepositTime()(uint256)"
call $T "maxCap()(uint256)"
call $T "utilizationMultiplier()(uint256)"
call $T "getUtilization()(uint256)"

echo; echo "-- Pool USDC 0x958cc922"
T=0x958cc92297e6F087f41A86125BA8E121F0FbEcF2
call $T "owner()(address)"
call $T "router()(address)"
call $T "trading()(address)"
call $T "currency()(address)"
call $T "rewards()(address)"
call $T "totalSupply()(uint256)"
call $T "openInterest()(uint256)"
call $T "withdrawFee()(uint256)"
call $T "minDepositTime()(uint256)"
call $T "maxCap()(uint256)"
call $T "utilizationMultiplier()(uint256)"
call $T "getUtilization()(uint256)"

echo; echo "-- PoolCAP 0xC8CDd2Ea"
T=0xC8CDd2Ea6A5149ced1F2d225D16a775ee081C67D
call $T "owner()(address)"
call $T "router()(address)"
call $T "cap()(address)"
call $T "totalSupply()(uint256)"

echo; echo "-- Store v3 0xf16033d2"
T=0xf16033d20adda47dc99ea291d0f4c4fef2ff47af
call $T "gov()(address)"
call $T "pool()(address)"
call $T "currency()(address)"
call $T "clp()(address)"
call $T "weth()(address)"
call $T "poolBalance()(uint256)"
call $T "bufferBalance()(uint256)"
call $T "getCLPSupply()(uint256)"
call $T "minimumMarginLevel()(uint256)"
call $T "poolFeeShare()(uint256)"
call $T "keeperFeeShare()(uint256)"
call $T "poolWithdrawalFee()(uint256)"
call $T "poolLastPaid()(uint256)"

echo; echo "-- CAP token 0x031d3529"
T=0x031d35296154279dc1984dcd93e392b1f946737b
call $T "name()(string)"
call $T "symbol()(string)"
call $T "totalSupply()(uint256)"
call $T "owner()(address)"
} | tee -a "$OUT"
echo "saved $OUT"
