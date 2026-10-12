#!/bin/bash
RPC=https://ethereum-rpc.publicnode.com
P=0x2638d2680AB4914126ee05b9c5EE95bAC311A95E
POOL=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
DAI=0x6B175474E89094C44Da98b954EedeAC495271d0F
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
TUSD=0x0000000000085d4780B73119b644AE5ecd22b376
SWRV=0xB8BAa0e4287890a5F79863aB62b7F175ceCbD433
GAUGE=0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa
MINTER=0x2c988c3974AD7E604E276AE0294a7228DEf67974
GC=0x0C4d90ca69104B4cb937fB21c8533c29554AE32c
VE=0xe5e7DdADD563018b0E692C1524b60b754FBD7f02
echo "== block =="; cast block-number --rpc-url $RPC
echo "== proxy admins =="
for f in ownership_admin parameter_admin emergency_admin future_ownership_admin future_parameter_admin future_emergency_admin; do echo -n "$f: "; cast call $P "$f()(address)" --rpc-url $RPC; done
echo "== burners =="
for t in $DAI $USDT $USDC $TUSD 0x0000000000000000000000000000000000000000; do echo -n "burners($t): "; cast call $P "burners(address)(address)" $t --rpc-url $RPC; done
echo "== balances =="
echo -n "proxy ETH: "; cast balance $P --rpc-url $RPC
for t in $DAI $USDT $USDC $TUSD $SWRV; do echo -n "proxy bal $t: "; cast call $t "balanceOf(address)(uint256)" $P --rpc-url $RPC; done
echo "== allowances of proxy as owner =="
echo -n "DAI.allowance(proxy,0xcDED..): "; cast call $DAI "allowance(address,address)(uint256)" $P 0xcDEDb901181b4B90181424Ff581b627805186Ca7 --rpc-url $RPC
echo -n "USDT.allowance(proxy,0x0): "; cast call $USDT "allowance(address,address)(uint256)" $P 0x0000000000000000000000000000000000000000 --rpc-url $RPC
echo "== pool state =="
for f in owner admin_fee future_admin_fee fee A admin_actions_deadline transfer_ownership_deadline future_owner; do echo -n "pool.$f: "; cast call $POOL "$f()(address)" --rpc-url $RPC 2>/dev/null || echo "ERR"; done
echo "== SWRV =="
for f in admin minter rate mining_epoch start_epoch_time totalSupply; do echo -n "SWRV.$f: "; cast call $SWRV "$f()(uint256)" --rpc-url $RPC 2>/dev/null; done
echo -n "SWRV.available_supply: "; cast call $SWRV "available_supply()(uint256)" --rpc-url $RPC
echo -n "SWRV.balanceOf(proxy): "; cast call $SWRV "balanceOf(address)(uint256)" $P --rpc-url $RPC
echo "== gauge =="
for f in "minter()(address)" "crv_token()(address)" "lp_token()(address)" "controller()(address)" "voting_escrow()(address)" "totalSupply()(uint256)" "working_supply()(uint256)" "period()(int128)" "inflation_rate()(uint256)" "future_epoch_time()(uint256)"; do echo -n "gauge.$f: "; cast call $GAUGE "$f" --rpc-url $RPC 2>/dev/null; done
echo -n "gauge.balanceOf(gauge): "; cast call $GAUGE "balanceOf(address)(uint256)" $GAUGE --rpc-url $RPC
echo -n "gauge.balanceOf(0xb4d0): own: "; cast call $GAUGE "balanceOf(address)(uint256)" $GAUGE --rpc-url $RPC
echo -n "gauge.integrate_checkpoint: "; cast call $GAUGE "integrate_checkpoint()(uint256)" --rpc-url $RPC
echo "== minter =="
for f in "token()(address)" "controller()(address)"; do echo -n "minter.$f: "; cast call $MINTER "$f" --rpc-url $RPC; done
echo "== gctrl =="
for f in "admin()(address)" "voting_escrow()(address)" "n_gauges()(int128)" "gauge_types(address)(int128):$GAUGE"; do echo -n "gc.$f: "; done
cast call $GC "admin()(address)" --rpc-url $RPC
cast call $GC "voting_escrow()(address)" --rpc-url $RPC
cast call $GC "n_gauges()(int128)" --rpc-url $RPC
cast call $GC "gauge_types(address)(int128)" $GAUGE --rpc-url $RPC
echo "== veSWRV =="
for f in "admin()(address)" "token()(address)" "supply()(uint256)" "totalSupply()(uint256)"; do echo -n "ve.$f: "; cast call $VE "$f" --rpc-url $RPC 2>/dev/null; done
echo -n "ve.locked(0x996E539a1242a541f5909c6B20BbEf4CC63F34b1): "; cast call $VE "locked(address)(int128,uint256)" 0x996E539a1242a541f5909c6B20BbEf4CC63F34b1 --rpc-url $RPC 2>/dev/null
echo -n "ve.balanceOf(gauge): "; cast call $VE "balanceOf(address)(uint256)" $GAUGE --rpc-url $RPC 2>/dev/null
echo "== proxy code size =="
cast codesize $P --rpc-url $RPC
