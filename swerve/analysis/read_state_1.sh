#!/usr/bin/env bash
# Swerve live-state read #1 (read-only). RPC from env only — never hardcode keyed URLs.
set -u
RPC="${RPC_URL:-https://ethereum-rpc.publicnode.com}"
P=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
IMPL=0xA5407eAE9Ba41422680e2e00537571bcC53efBfD
echo "== block =="
cast block-number --rpc-url "$RPC"
echo "== delegator storage vars =="
for fn in "owner()(address)" "A()(uint256)" "fee()(uint256)" "admin_fee()(uint256)" "admin_actions_deadline()(uint256)" "transfer_ownership_deadline()(uint256)" "future_owner()(address)" "future_A()(uint256)" "future_fee()(uint256)" "future_admin_fee()(uint256)" "totalSupply()(uint256)"; do
  printf "%-32s %s\n" "$fn" "$(cast call $P "$fn" --rpc-url "$RPC" 2>&1 | head -1)"
done
echo "== coins / underlying_coins / balances =="
for i in 0 1 2 3; do
  echo "  [$i] coin=$(cast call $P "coins(int128)(address)" $i --rpc-url "$RPC") under=$(cast call $P "underlying_coins(int128)(address)" $i --rpc-url "$RPC") bal=$(cast call $P "balances(int128)(uint256)" $i --rpc-url "$RPC")"
done
echo "== impl probes (is_killed etc, via delegator delegatecall) =="
for fn in "is_killed()(bool)" "kill_deadline()(uint256)" "token()(address)" "name()(string)" "symbol()(string)" "decimals()(uint256)" "get_virtual_price()(uint256)" "minter()(address)"; do
  printf "%-32s %s\n" "$fn" "$(cast call $P "$fn" --rpc-url "$RPC" 2>&1 | head -1)"
done
echo "== direct ERC20 balanceOf(pool) =="
for tok in 0x6B175474E89094C44Da98b954EedeAC495271d0F:Dai 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48:USDC 0xdAC17F958D2ee523a2206206994597C13D831ec7:USDT 0x0000000000085d4780B73119b644AE5ecd22b376:TUSD 0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01:yDAI 0xd6aD7a6750A7593E092a9B218d66C0A814a3436e:yUSDC 0x83f798e925BcD4017Eb265844FDDAbb448f1707D:yUSDT 0x73a052500105205d34Df699586754fa1eA0757CF:yTUSD; do
  addr="${tok%%:*}"; sym="${tok##*:}"
  printf "%-6s %s\n" "$sym" "$(cast call $addr "balanceOf(address)(uint256)" $P --rpc-url "$RPC" 2>&1 | head -1)"
done
echo "== code sizes =="
echo "delegator: $(cast code $P --rpc-url "$RPC" | wc -c) hex chars"
echo "impl:      $(cast code $IMPL --rpc-url "$RPC" | wc -c) hex chars"
