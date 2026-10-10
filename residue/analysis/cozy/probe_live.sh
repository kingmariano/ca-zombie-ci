#!/usr/bin/env bash
# Read-only live-state probe for Cozy Finance v2 Sets on Optimism.
# Public RPC only. No secrets. Output: TSV -> stdout.
set -u
RPC=${RPC:-https://optimism-rpc.publicnode.com}
BN=$(cast block-number --rpc-url "$RPC")
echo "BLOCK	$BN"

call1() { # addr sig [args...]
  local addr=$1 sig=$2; shift 2
  local out rc
  out=$(cast call "$addr" "$sig" "$@" --rpc-url "$RPC" 2>&1); rc=$?
  printf '%s\t%s\t%s\t%s\n' "$addr" "$sig" "$rc" "$(echo "$out" | head -3 | tr '\n' ' ')"
}

SETS="0x17705474203F7ff7ba8a940c433AB43D1F58E249 0x1a684C688AcA00944B22B9380219c7bBbC3B7fB9 0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8 0xfB8b6E5b35b70324701adE10dafbdEFb8D0EB276"
MKTSIG="markets(uint256)(address,address,(address,address,uint16,uint16,uint16),uint8,uint256,uint256,uint256,uint128,uint128,uint64)"

echo "== SET IDENTITY/STATE"
for S in $SETS; do
  call1 $S "asset()(address)"
  call1 $S "name()(string)"
  call1 $S "symbol()(string)"
  call1 $S "decimals()(uint8)"
  call1 $S "totalSupply()(uint256)"
  call1 $S "totalCollateralAvailable()(uint256)"
  call1 $S "maxDeposit()(uint256)"
  call1 $S "setState()(uint8)"
  call1 $S "owner()(address)"
  call1 $S "pauser()(address)"
  call1 $S "manager()(address)"
  call1 $S "backstop()(address)"
  call1 $S "ptokenFactory()(address)"
  call1 $S "setConfig()(uint32,uint16,bool)"
  call1 $S "accounting()(uint128,uint128,uint128,uint128,uint128,uint128,uint128)"
  call1 $S "lastConfigUpdate()(bytes32,uint64,uint64)"
  for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    call1 $S "$MKTSIG" $i
  done
done

echo "== MARKETS DETAIL (index per set)"
for S in $SETS; do
  for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    call1 $S "remainingProtection(uint16)(uint256)" $i
    call1 $S "effectiveActiveProtection(uint16)(uint256)" $i
    call1 $S "previewPurchase(uint16,uint256)(uint128,uint128,uint128,uint128,uint128)" $i 1000000000
    call1 $S "previewClaim(uint16,uint256)(uint128)" $i 1000000000
    call1 $S "previewClaim(uint16,uint256)(uint128)" $i 1
    call1 $S "previewSale(uint16,uint256)(uint128,uint128,uint128,uint128)" $i 1000000000
  done
done

echo "== CSET CONVERSION"
for S in $SETS; do
  call1 $S "convertToAssets(uint256)(uint256)" 1000000
  call1 $S "convertToShares(uint256)(uint256)" 1000000
done

echo "== CPT TOKENS"
CPTS="0xC1304c0Db0bb2001e11E5c45ecb4F3D0e7158655 0xFa1c5663aCeC49aD17422d2E846eA113534a8abf 0x1F626C96Ed2AedB69DfF96B653F733b1767E9cce 0x2086DcfB21761183ed0b20812F61F0984096AF99 0x658CeBADEa3a833EB7E186bE626Ae88496A6F76E 0xcFA3560c768946446e9B8fbd734Be7b2a39dAB6F 0x996e0a0A3801A3F642be2c5A4745BF9d526fA668 0x17aFF89bf88B4eB56a1bCB256ff49FA1910E8410"
for T in $CPTS; do
  call1 $T "name()(string)"
  call1 $T "symbol()(string)"
  call1 $T "decimals()(uint8)"
  call1 $T "totalSupply()(uint256)"
  call1 $T "set()(address)"
  call1 $T "balanceOf(address)(uint256)" 0x9E47C805587362eF36F2cAB9d1E4E7D546f953d4
  call1 $T "balanceOf(address)(uint256)" 0xeF9886f4C8823Dc9457267A7b76A55Db2C2f5F8d
  call1 $T "balanceOf(address)(uint256)" 0x003FE7359A4E03C85Ac2f521eC699ED84C7c5ccB
done

echo "== TRIGGERS"
TRIGGERS="0xeB6613FAC35fED17c276e3FE45D67Da67685f1eF 0xaCD105FEEa362D5c27CAAbA0B45F53D91B92dE27 0x41701936CD5F4B8F5284dB0C68f0c2B9dF3B1618"
for T in $TRIGGERS; do
  call1 $T "state()(uint8)"
  call1 $T "oracle()(address)"
  call1 $T "bondAmount()(uint256)"
  call1 $T "proposalDisputeWindow()(uint256)"
  call1 $T "rewardToken()(address)"
  call1 $T "requestTimestamp()(uint256)"
  call1 $T "queryIdentifier()(bytes32)"
  call1 $T "query()(string)"
  call1 $T "expirationTime()(uint256)"
done

echo "== OTHER CONTRACTS"
for A in 0x7eDfAd1b566657a236C8422bA6997536BC647a29 0xbfc907920a9D9E11A356727F43b6c56ae2774add 0x17aFF89bf88B4eB56a1bCB256ff49FA1910E8410; do
  call1 $A "name()(string)"
  call1 $A "symbol()(string)"
  call1 $A "asset()(address)"
  call1 $A "totalSupply()(uint256)"
  call1 $A "owner()(address)"
done
