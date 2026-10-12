#!/usr/bin/env bash
# Swerve live-state read #2: storage-layout forensics (read-only).
set -u
RPC="${RPC:-https://ethereum-rpc.publicnode.com}"
P=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
IMPL=0xA5407eAE9Ba41422680e2e00537571bcC53efBfD
# Solidity array base slots for delegator: _coins slot0, _underlying_coins slot1, _balances slot2
K0=0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563
K1=0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
K2=0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace
addhex() { python3 -c "print(hex(int('$1',16)+$2))"; }
echo "== raw slots of POOL (Solidity-delegator layout expected) =="
for s in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do printf "slot %-2s %s\n" "$s" "$(cast storage $P $s --rpc-url $RPC)"; done
echo "== Solidity dynamic-array element slots of POOL =="
for i in 0 1 2 3; do
  printf "_coins[%s]           %s\n" "$i" "$(cast storage $P $(addhex $K0 $i) --rpc-url $RPC)"
  printf "_underlying_coins[%s] %s\n" "$i" "$(cast storage $P $(addhex $K1 $i) --rpc-url $RPC)"
  printf "_balances[%s]         %s\n" "$i" "$(cast storage $P $(addhex $K2 $i) --rpc-url $RPC)"
done
echo "== pool getters (Solidity-side, delegator functions) =="
for i in 0 1 2 3; do
  printf "coins(%s)=%s  under(%s)=%s  bal(%s)=%s\n" "$i" "$(cast call $P 'coins(int128)(address)' $i --rpc-url $RPC 2>&1 | head -1)" "$i" "$(cast call $P 'underlying_coins(int128)(address)' $i --rpc-url $RPC 2>&1 | head -1)" "$i" "$(cast call $P 'balances(int128)(uint256)' $i --rpc-url $RPC 2>&1 | head -1)"
done
for fn in "totalSupply()(uint256)" "A()(uint256)" "fee()(uint256)" "admin_fee()(uint256)" "owner()(address)" "get_virtual_price()(uint256)" "name()(string)" "symbol()(string)" "decimals()(uint256)" "admin_actions_deadline()(uint256)" "transfer_ownership_deadline()(uint256)" "future_owner()(address)" "future_A()(uint256)" "future_fee()(uint256)" "future_admin_fee()(uint256)"; do
  printf "%-40s %s\n" "$fn" "$(cast call $P "$fn" --rpc-url $RPC 2>&1 | head -1)"
done
printf "%-40s %s\n" "get_dy(0,1,1e18)" "$(cast call $P 'get_dy(int128,int128,uint256)(uint256)' 0 1 1000000000000000000 --rpc-url $RPC 2>&1 | head -1)"
printf "%-40s %s\n" "get_dy(0,2,1e18)" "$(cast call $P 'get_dy(int128,int128,uint256)(uint256)' 0 2 1000000000000000000 --rpc-url $RPC 2>&1 | head -1)"
echo "== impl's OWN storage (0xA5407eAE) slots 0..16 =="
for s in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do printf "impl slot %-2s %s\n" "$s" "$(cast storage $IMPL $s --rpc-url $RPC)"; done
echo "== direct ERC20 balanceOf(pool) =="
for tok in 0x6B175474E89094C44Da98b954EedeAC495271d0F:Dai 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48:USDC 0xdAC17F958D2ee523a2206206994597C13D831ec7:USDT 0x0000000000085d4780B73119b644AE5ecd22b376:TUSD; do
  addr="${tok%%:*}"; sym="${tok##*:}"
  printf "%-5s %s\n" "$sym" "$(cast call $addr 'balanceOf(address)(uint256)' $P --rpc-url $RPC 2>&1 | head -1)"
done
