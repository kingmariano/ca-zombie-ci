#!/usr/bin/env bash
# Purrlend (C2-21) — reproducible read-only checks against PUBLIC, keyless RPCs.
# Nothing here signs or sends a transaction; all calls are eth_call / eth_getLogs / eth_getCode.
# Usage: bash repro.sh   (cast + curl required)
set -euo pipefail

H=https://rpc.hyperliquid.xyz/evm        # HyperEVM chain 999
M=https://mainnet.megaeth.com/rpc        # MegaETH chain 4326

HACL=0x507Bc877A27baEB12BE4Df42EfAA949A9A67703d
MACL=0x217214BbF25F02A8019d42EA315aB192540aDa13
HPROV=0xf33e33B35163Ce2f46bf7150E1592839aC199124
MPROV=0x402D38C3415Ad92a0E766e1491Dc222871B1Df7a
HPOOL=0xb61218d3efE306f7579eE50D1a606d56bc222048
MPOOL=0x81D5D25ea81b72E546fC71B5bAa8B059eF0dA702
SAFE=0x4c2444d88AD61B0842Fba7CCdCb226260eBfA1bc
EOA=0x6056BE985DD4c50fECA34130FeDD0a35857099FD
BRIDGE=0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278
POOLADMIN=0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b
DEFAULT=0x0000000000000000000000000000000000000000000000000000000000000000

echo "### blocks"
cast block-number --rpc-url $H; cast block-number --rpc-url $M

echo "### ACL role admins and live holders"
for rpc in "$H $HACL" "$M $MACL"; do set -- $rpc; echo "-- $1 $2";
  echo -n "getRoleAdmin(BRIDGE): "; cast call $2 "getRoleAdmin(bytes32)(bytes32)" $BRIDGE --rpc-url $1
  for who in $SAFE $EOA; do
    echo -n "  DEFAULT_ADMIN($who): "; cast call $2 "hasRole(bytes32,address)(bool)" $DEFAULT $who --rpc-url $1
    echo -n "  BRIDGE($who):        "; cast call $2 "hasRole(bytes32,address)(bool)" $BRIDGE $who --rpc-url $1
  done
done

echo "### provider ownership"
echo -n "H owner: "; cast call $HPROV "owner()(address)" --rpc-url $H
echo -n "M owner: "; cast call $MPROV "owner()(address)" --rpc-url $M
echo -n "H getACLAdmin: "; cast call $HPROV "getACLAdmin()(address)" --rpc-url $H
echo -n "M getACLAdmin: "; cast call $MPROV "getACLAdmin()(address)" --rpc-url $M

echo "### Safe setup (both chains use the same Safe)"
cast call $SAFE "getThreshold()(uint256)" --rpc-url $H
cast call $SAFE "getOwners()(address[])" --rpc-url $H

echo "### fresh unprivileged attacker cannot grant BRIDGE (expect revert)"
cast call $HACL "grantRole(bytes32,address)" $BRIDGE 0x000000000000000000000000000000000000F8e5 --from 0x000000000000000000000000000000000000F8e5 --rpc-url $H || true

echo "### reserve lists"
cast call $HPOOL "getReservesList()(address[])" --rpc-url $H
cast call $MPOOL "getReservesList()(address[])" --rpc-url $M

echo "### idle liquidity behind each aToken (the only cash any withdraw can pull)"
# HyperEVM USDC aToken / sUSDp aToken
echo -n "H aUSDC idle:  "; cast call 0xb88339CB7199b77E23DB6E890353E22632Ba630f "balanceOf(address)(uint256)" 0x1A77d9f5E760586172F8dc2cE0e6c5ef7C5d4678 --rpc-url $H
echo -n "H aSUSDp idle: "; cast call 0x9B3a8f7CEC208e247d97dEE13313690977e24459 "balanceOf(address)(uint256)" 0xD9ADD9cBF568BB82c2d0ECc08f657486dc6d6696 --rpc-url $H
echo -n "M aUSDm idle:  "; cast call 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7 "balanceOf(address)(uint256)" 0x1e7c2beC64062098A192118d1708DaD717C9C5fC --rpc-url $M
echo -n "M aGLV idle:   "; cast call 0x3782d91C5888dE31F627495e6aAAC3f09499fe72 "balanceOf(address)(uint256)" 0x95Da1Cd5A66D3758996356d7F6cEcA55bbBfb087 --rpc-url $M

echo "### unbacked counters (USDC on HyperEVM, USDm on MegaETH) - see getReserveData last-2 fields"
SIG="getReserveData(address)((uint256,uint128,uint128,uint128,uint128,uint128,uint40,uint16,address,address,address,address,uint128,uint128,uint128))"
cast call $HPOOL "$SIG" 0xb88339CB7199b77E23DB6E890353E22632Ba630f --rpc-url $H
cast call $MPOOL "$SIG" 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7 --rpc-url $M

echo "### attacker phantom aTokens (unredeemable)"
echo -n "H aUSDC(attacker): "; cast call 0x1A77d9f5E760586172F8dc2cE0e6c5ef7C5d4678 "balanceOf(address)(uint256)" 0xd8010aca201f6113160200b8a521F35BE9f94C24 --rpc-url $H
echo -n "M aUSDm(attacker): "; cast call 0x1e7c2beC64062098A192118d1708DaD717C9C5fC "balanceOf(address)(uint256)" 0xd8010aca201f6113160200b8a521F35BE9f94C24 --rpc-url $M

echo "### fork tests"
echo "cd poc && forge test -vv"
