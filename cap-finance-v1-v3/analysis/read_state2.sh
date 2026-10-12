#!/usr/bin/env bash
# Read remaining live Cap Finance state on Arbitrum (read-only). No secrets in output.
set -u
export PATH="$PATH:$HOME/.foundry/bin"
RPC="${ARB_RPC:-https://arb1.arbitrum.io/rpc}"
OUT="$(dirname "$0")/state/state-live2.txt"
mkdir -p "$(dirname "$OUT")"

call() {
  local a="$1"; shift
  printf "%-46s %-42s " "$a" "$*"
  timeout 25 cast call "$a" "$@" --rpc-url "$RPC" 2>&1 | head -2 | tr '\n' ' '
  echo
}

BLK=$(cast block-number --rpc-url "$RPC")
{
echo "block=$BLK"

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

echo; echo "-- v2 router 0x5ABFF8F8"
T=0x5ABFF8F8D5b13253dCAB1e427Fdb3305cA620119
call $T "trading()(address)"
call $T "oracle()(address)"
call $T "treasury()(address)"
call $T "darkOracle()(address)"
call $T "currenciesLength()(uint256)"
call $T "getPool(address)(address)" 0x0000000000000000000000000000000000000000
call $T "getPool(address)(address)" 0xff970a61a04b1ca14834a43f5de4533ebddb5cc8

echo; echo "-- v2 treasury 0x283C41b7"
T=0x283C41b726634fBD6B72aA22741B202DB7E56aaC
call $T "owner()(address)"
echo "code:" $(cast code $T --rpc-url "$RPC" | head -c 20)

echo; echo "-- v3 owner 0xDd5ee4e1 / v2 owner 0x59eE1271 / v1 owner 0xAD364Da8"
for A in 0xDd5ee4e1a7fE06e0C30078292C94D889380d6d55 0x59eE12714dFCFC300344f0256A4308c1C48E56ED 0xAD364Da879C7AaFb519d5eaf07441D79BAcAbbbb; do
  echo "$A code=$(cast code $A --rpc-url "$RPC" | head -c 12)"
done

echo; echo "-- rewards contracts"
for A in 0x29163356bBAF0a3bfeE9BA5a52a5C6463114Cb5f; do
  call $A "owner()(address)"
  call $A "totalSupply()(uint256)"
  call $A "rewardsToken()(address)"
  call $A "stakingToken()(address)"
done
} | tee "$OUT"
echo "saved $OUT"
