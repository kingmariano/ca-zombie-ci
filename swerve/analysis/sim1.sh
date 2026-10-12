#!/bin/bash
RPC=https://ethereum-rpc.publicnode.com
P=0x2638d2680AB4914126ee05b9c5EE95bAC311A95E
POOL=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
DAI=0x6B175474E89094C44Da98b954Eedeac495271d0F
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
TUSD=0x0000000000085d4780B73119b644AE5ecd22b376
ATT=0x1111111111111111111111111111111111111111
echo "### E-U attempt: burn_coin(USDT) from attacker ($(cast block-number --rpc-url $RPC))"
cast call $P "burn_coin(address)" $USDT --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: burn_coin(DAI) from attacker (burner=0xcDED, DAI bal=0)"
cast call $P "burn_coin(address)" $DAI --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: burn_coin(USDC) from attacker (burner=0xcDED)"
cast call $P "burn_coin(address)" $USDC --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: burn_coin(random coin 0x00..01) burners=0x0"
cast call $P "burn_coin(address)" 0x0000000000000000000000000000000000000001 --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: burn_eth from attacker"
cast call $P "burn_eth()" --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: burn(0xcDED) from attacker (direct Burner.burn call)"
cast call $P "burn(address)" 0xcDEDb901181b4B90181424Ff581b627805186Ca7 --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: withdraw_admin_fees(pool) from attacker"
cast call $P "withdraw_admin_fees(address)" $POOL --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: apply_transfer_ownership(pool) from attacker"
cast call $P "apply_transfer_ownership(address)" $POOL --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: apply_new_parameters(pool) from attacker"
cast call $P "apply_new_parameters(address)" $POOL --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: apply_new_fee(pool) from attacker"
cast call $P "apply_new_fee(address)" $POOL --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### E-U attempt: set_burner(USDT, attacker) from attacker -> expect Access denied"
cast call $P "set_burner(address,address)" $USDT $ATT --from $ATT --rpc-url $RPC; echo "rc=$?"
echo "### P attempt: set_burner(USDT, attacker) from admin EOA"
cast call $P "set_burner(address,address)" $USDT $ATT --from 0x996E539a1242a541f5909c6B20BbEf4CC63F34b1 --rpc-url $RPC; echo "rc=$?"
echo "### P attempt: apply_set_admins from admin EOA (future==current, no-op)"
cast call $P "apply_set_admins()" --from 0x996E539a1242a541f5909c6B20BbEf4CC63F34b1 --rpc-url $RPC; echo "rc=$?"
echo "### P attempt: donate_admin_fees(pool) from admin EOA"
cast call $P "donate_admin_fees(address)" $POOL --from 0x996E539a1242a541f5909c6B20BbEf4CC63F34b1 --rpc-url $RPC; echo "rc=$?"
echo "### P attempt: commit_transfer_ownership(pool,attacker) from admin EOA (pool owner=0 -> expect revert)"
cast call $P "commit_transfer_ownership(address,address)" $POOL $ATT --from 0x996E539a1242a541f5909c6B20BbEf4CC63F34b1 --rpc-url $RPC; echo "rc=$?"
echo "### proxy allowances (USDC,TUSD to 0xcDED)"
for t in $USDC $TUSD; do echo -n "$t: "; cast call $t "allowance(address,address)(uint256)" $P 0xcDEDb901181b4B90181424Ff581b627805186Ca7 --rpc-url $RPC; done
