#!/usr/bin/env bash
# Light live-state dump for the Swapr V3 (Gnosis) deep-dive.
# Public keyless RPC only — never print or store secrets.
set -uo pipefail
RPC="https://rpc.gnosischain.com"
OUT="ci-out"
mkdir -p "$OUT"

B=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo 0)
F=0xA0864cCA6E114013AB0e27cbd5B6f4c8947da766
P=0xA8bE29B73c9752AEB3DB3aa78f171861079685C7
H=0x216D3DF2DF6DeC7c95D3b51F018eE4b11E416eBb
C=0x1E86A593E55215957C4755f1BE19a229AF3286f6
V=0x187E0966046dA5b110Fdc986c9B94Bd8416837AF
WETH=0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1
WST=0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6

cat > "$OUT/live_state.json" <<EOF
{
  "block": $B,
  "factory_owner": "$(cast call --rpc-url "$RPC" $F 'owner()(address)' 2>/dev/null)",
  "factory_farming": "$(cast call --rpc-url "$RPC" $F 'farmingAddress()(address)' 2>/dev/null)",
  "factory_vault": "$(cast call --rpc-url "$RPC" $F 'vaultAddress()(address)' 2>/dev/null)",
  "default_community_fee": "$(cast call --rpc-url "$RPC" $F 'defaultCommunityFee()(uint8)' 2>/dev/null)",
  "pool_liquidity": "$(cast call --rpc-url "$RPC" $P 'liquidity()(uint128)' 2>/dev/null)",
  "pool_weth": "$(cast call --rpc-url "$RPC" $WETH 'balanceOf(address)(uint256)' $P 2>/dev/null)",
  "pool_wsteth": "$(cast call --rpc-url "$RPC" $WST 'balanceOf(address)(uint256)' $P 2>/dev/null)",
  "pool_global_state": "$(cast call --rpc-url "$RPC" $P 'globalState()(uint160,int24,uint16,uint16,uint8,uint8,bool)' 2>/dev/null | tr '\n' '|')",
  "hypervisor_supply": "$(cast call --rpc-url "$RPC" $H 'totalSupply()(uint256)' 2>/dev/null)",
  "hypervisor_totals": "$(cast call --rpc-url "$RPC" $H 'getTotalAmounts()(uint256,uint256)' 2>/dev/null | tr '\n' '|')",
  "hypervisor_owner": "$(cast call --rpc-url "$RPC" $H 'owner()(address)' 2>/dev/null)",
  "hypervisor_whitelist": "$(cast call --rpc-url "$RPC" $H 'whitelistedAddress()(address)' 2>/dev/null)",
  "clearing_paused": "$(cast call --rpc-url "$RPC" $C 'paused()(bool)' 2>/dev/null)",
  "clearing_twapCheck": "$(cast call --rpc-url "$RPC" $C 'twapCheck()(bool)' 2>/dev/null)",
  "clearing_position": "$(cast call --rpc-url "$RPC" $C 'positions(address)(bool,bool,bool,bool,bool,uint8,uint32,uint256,uint256,uint256,uint256,uint256,uint256,uint256)' $H 2>/dev/null | tr '\n' '|')",
  "v3fees_owner": "$(cast call --rpc-url "$RPC" $V 'owner()(address)' 2>/dev/null)",
  "v3fees_usdce": "$(cast call --rpc-url "$RPC" 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0 'balanceOf(address)(uint256)' $V 2>/dev/null)"
}
EOF
echo "wrote $OUT/live_state.json"
cat "$OUT/live_state.json"
