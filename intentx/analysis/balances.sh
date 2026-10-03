#!/usr/bin/env bash
set -u
# diamond, collateral, rpc
data=(
"base|0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43|0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913|https://base-rpc.publicnode.com"
"mantle|0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5|0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34|https://rpc.mantle.xyz"
"arbitrum|0x8F06459f184553e5d04F07F868720BDaCAB39395|0xaf88d065e77c8cC2239327C5EDb3A432268e5831|https://arb1.arbitrum.io/rpc"
"blast|0x3d17f073cCb9c3764F105550B0BCF9550477D266|0x4300000000000000000000000000000000000003|https://blast-rpc.publicnode.com"
)
for row in "${data[@]}"; do
  IFS='|' read -r chain sym col rpc <<< "$row"
  echo "### $chain"
  echo -n "collateral symbol/decimals: "; cast call --rpc-url $rpc $col "symbol()(string)" 2>/dev/null | tr -d '\n'; echo -n " / "; cast call --rpc-url $rpc $col "decimals()(uint8)" 2>/dev/null
  echo -n "diamond collateral balance: "; cast call --rpc-url $rpc $col "balanceOf(address)(uint256)" $sym 2>/dev/null
  echo -n "diamond native balance: "; cast balance --rpc-url $rpc $sym 2>/dev/null
  echo -n "facetAddresses: "; cast call --rpc-url $rpc $sym "facetAddresses()(address[])" 2>/dev/null
done
