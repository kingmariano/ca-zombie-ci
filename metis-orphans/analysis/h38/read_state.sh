#!/bin/bash
# H-38 state snapshot at a pinned block (read-only)
RPC="https://andromeda.metis.io/?owner=1088"
BLK="${BLK:-23238721}"
OUT="${1:-raw/state_snapshot.txt}"
: > "$OUT"
say(){ echo "$@" | tee -a "$OUT"; }

r(){ cast call --rpc-url "$RPC" --block "$BLK" "$1" "$2" "${@:3}" 2>&1; }

say "block=$BLK rpc=$RPC"
say "== factory =="
say "feeTo:        $(r 0x70f51d68D16e8f9e418441280342BD43AC9Dff9f 'feeTo()(address)')"
say "feeRate:      $(r 0x70f51d68D16e8f9e418441280342BD43AC9Dff9f 'feeRate()(uint256)')"
say "feeToSetter:  $(r 0x70f51d68D16e8f9e418441280342BD43AC9Dff9f 'feeToSetter()(address)')"
say "allPairsLen:  $(r 0x70f51d68D16e8f9e418441280342BD43AC9Dff9f 'allPairsLength()(uint256)')"
say "owner:        $(r 0x70f51d68D16e8f9e418441280342BD43AC9Dff9f 'owner()(address)')"

for P in 0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1 0x59051B5F5172b69E66869048Dc69D35dB0B3610d 0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091 0x9dAbD9257E55230Fa17415BF9a6946085f533a00; do
  say "== pair $P =="
  T0=$(r "$P" 'token0()(address)'); T1=$(r "$P" 'token1()(address)')
  say "token0=$T0"
  say "token1=$T1"
  say "getReserves: $(r "$P" 'getReserves()(uint112,uint112,uint32)')"
  say "totalSupply: $(r "$P" 'totalSupply()(uint256)')"
  say "bal0=$T0: $(r "$T0" 'balanceOf(address)(uint256)' "$P")"
  say "bal1=$T1: $(r "$T1" 'balanceOf(address)(uint256)' "$P")"
  say "selfLP:      $(r "$P" 'balanceOf(address)(uint256)' "$P")"
  say "kLast:       $(r "$P" 'kLast()(uint256)')"
  say "factory:     $(r "$P" 'factory()(address)')"
  say "tokenX meta: name0=$(r "$T0" 'name()(string)') sym0=$(r "$T0" 'symbol()(string)') dec0=$(r "$T0" 'decimals()(uint8)')"
  say "tokenX meta: name1=$(r "$T1" 'name()(string)') sym1=$(r "$T1" 'symbol()(string)') dec1=$(r "$T1" 'decimals()(uint8)')"
done
