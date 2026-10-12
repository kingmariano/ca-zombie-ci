#!/usr/bin/env bash
# childA probe #1: Swerve pool (0x3292) identity, LP-minter forensics, dust checks,
# admin-function deadness. READ-ONLY (eth_call / eth_getStorageAt only). No keys.
set -u
RPC="${RPC:-https://ethereum-rpc.publicnode.com}"
BN="${BN:-26173859}"
P=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
IMPL=0xA5407eAE9Ba41422680e2e00537571bcC53efBfD
LP=0x77c6e4a580c0dce4e5c7a17d0bc077188a83a059
GAUGE=0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa
MINTER=0x2c988c3974AD7E604E276AE0294a7228DEf67974
DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
TUSD=0x0000000000085d4780B73119b644AE5ecd22b376
ATT=0x1111111111111111111111111111111111111111

call() { local desc="$1"; shift; local out; out=$(cast call "$@" --rpc-url "$RPC" --block "$BN" 2>&1); local rc=$?; printf "%-58s rc=%s :: %s\n" "$desc" "$rc" "$(printf '%s' "$out" | head -1)"; }

echo "== identity =="
echo "block=$BN"
echo "pool code hdr:  $(cast code $P --rpc-url $RPC --block $BN | head -c 42)..."
echo "impl code hdr:  $(cast code $IMPL --rpc-url $RPC --block $BN | head -c 42)..."
echo -n "pool runtime code contains impl target 73a5407eae...: "
cast code $P --rpc-url $RPC --block $BN | tr 'A-F' 'a-f' | grep -c '73a5407eae9ba41422680e2e00537571bcc53efbfd'
echo "impl own coins (proves 0xA5407eAE is itself Curve sUSD pool):"
for i in 0 1 2 3; do
  k=$(python3 -c "print(hex(int(0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563,16)+$i))")
  printf "  impl _coins[%s] = %s\n" "$i" "$(cast storage $IMPL $k --rpc-url $RPC --block $BN)"
done
echo "impl own slot6 owner = $(cast storage $IMPL 6 --rpc-url $RPC --block $BN)"
echo "impl own slot7 token = $(cast storage $IMPL 7 --rpc-url $RPC --block $BN)"

echo
echo "== pool storage slots 6..15 =="
for s in 6 7 8 9 10 11 12 13 14 15; do printf "  slot %-2s %s\n" "$s" "$(cast storage $P $s --rpc-url $RPC --block $BN)"; done

echo
echo "== LP token (swUSD) forensics =="
call "LP totalSupply()"             $LP 'totalSupply()(uint256)'
call "LP balanceOf(pool)"           $LP 'balanceOf(address)(uint256)' $P
call "LP balanceOf(gauge)"          $LP 'balanceOf(address)(uint256)' $GAUGE
call "LP balanceOf(gaugeself)"      $LP 'balanceOf(address)(uint256)' $GAUGE
call "LP set_minter(ATT) from POOL" $LP 'set_minter(address)' $ATT --from $P
call "LP set_minter(ATT) from ATT " $LP 'set_minter(address)' $ATT --from $ATT
call "LP mint(ATT,1) from POOL"     $LP 'mint(address,uint256)' $ATT 1 --from $P
call "LP mint(ATT,1) from ATT "     $LP 'mint(address,uint256)' $ATT 1 --from $ATT
call "LP burnFrom(ATT,1) from POOL" $LP 'burnFrom(address,uint256)' $ATT 1 --from $P
call "LP burnFrom(ATT,1) from ATT " $LP 'burnFrom(address,uint256)' $ATT 1 --from $ATT
call "LP transferFrom(gauge,ATT,1) from POOL(minter?)" $LP 'transferFrom(address,address,uint256)' $GAUGE $ATT 1 --from $P
call "LP transferFrom(gauge,ATT,1) from ATT"          $LP 'transferFrom(address,address,uint256)' $GAUGE $ATT 1 --from $ATT

echo
echo "== dust probes: get_dy(i,j,0) for all ordered pairs =="
for i in 0 1 2 3; do for j in 0 1 2 3; do
  if [ "$i" != "$j" ]; then
    call "get_dy($i,$j,0)" $P 'get_dy(int128,int128,uint256)(uint256)' $i $j 0
  fi
done; done

echo
echo "== get_dy vs get_dy_underlying equality =="
for spec in "0 1 1000000000000000000" "1 0 1000000" "0 2 1000000000000000000" "2 0 1000000" "0 3 1000000000000000000" "3 0 1000000000000000000" "1 2 1000000" "2 1 1000000" "1 3 1000000" "3 1 1000000000000000000" "2 3 1000000" "3 2 1000000000000000000"; do
  set -- $spec
  a=$(cast call $P 'get_dy(int128,int128,uint256)(uint256)' $1 $2 $3 --rpc-url $RPC --block $BN 2>&1 | head -1)
  b=$(cast call $P 'get_dy_underlying(int128,int128,uint256)(uint256)' $1 $2 $3 --rpc-url $RPC --block $BN 2>&1 | head -1)
  printf "  pair(%s->%s) dx=%s  dy=%s  dy_underlying=%s  equal=%s\n" "$1" "$2" "$3" "$a" "$b" "$([ "$a" = "$b" ] && echo YES || echo NO)"
done

echo
echo "== admin function deadness (attacker = $ATT) =="
call "owner()" $P 'owner()(address)'
call "withdraw_admin_fees() from ATT" $P 'withdraw_admin_fees()' --from $ATT
call "kill_me() from ATT"             $P 'kill_me()' --from $ATT
call "unkill_me() from ATT"           $P 'unkill_me()' --from $ATT
call "commit_new_parameters from ATT" $P 'commit_new_parameters(uint256,uint256,uint256)' 100 3000000 0 --from $ATT
call "apply_new_parameters from ATT"  $P 'apply_new_parameters()' --from $ATT
call "commit_transfer_ownership from ATT" $P 'commit_transfer_ownership(address)' $ATT --from $ATT
call "apply_transfer_ownership from ATT"  $P 'apply_transfer_ownership()' --from $ATT

echo
echo "== zero-dx exchange reachability (no balance/allowance needed) =="
call "exchange(0,1,0,0) from ATT" $P 'exchange(int128,int128,uint256,uint256)' 0 1 0 0 --from $ATT
call "exchange(3,0,0,0) from ATT" $P 'exchange(int128,int128,uint256,uint256)' 3 0 0 0 --from $ATT

echo
echo "== pool allowances to others (approve paths in impl are lending-only) =="
call "DAI allowance(pool,pool)"  $DAI 'allowance(address,address)(uint256)' $P $P
call "USDC allowance(pool,pool)" $USDC 'allowance(address,address)(uint256)' $P $P
call "USDT allowance(pool,pool)" $USDT 'allowance(address,address)(uint256)' $P $P
call "TUSD allowance(pool,pool)" $TUSD 'allowance(address,address)(uint256)' $P $P

echo
echo "== gauge0xb4d0 + minter info =="
call "gauge.lp_token()"     $GAUGE 'lp_token()(address)'
call "gauge.totalSupply()"  $GAUGE 'totalSupply()(uint256)'
call "gauge.minter()"       $GAUGE 'minter()(address)'
call "gauge.crv_token()"    $GAUGE 'crv_token()(address)'
call "gauge.balanceOf(pool)" $GAUGE 'balanceOf(address)(uint256)' $P
call "minter.token()"       $MINTER 'token()(address)'
call "minter.controller()"  $MINTER 'controller()(address)'
echo "gauge code size: $(cast code $GAUGE --rpc-url $RPC --block $BN | wc -c)"
echo "minter code size: $(cast code $MINTER --rpc-url $RPC --block $BN | wc -c)"
