#!/usr/bin/env bash
# Endpoint probe (light, read-only). Usage: bash probe.sh
probe() { # name url data
  local name="$1" url="$2" data="$3"
  local out
  out=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' --data "$data" "$url" 2>/dev/null | head -c 220)
  if [ -n "$out" ]; then echo "OK   $name :: $out"; else echo "FAIL $name :: $url"; fi
}
probe_get() {
  local name="$1" url="$2"
  local out
  out=$(curl -s -m 12 "$url" -H 'User-Agent: Mozilla/5.0' 2>/dev/null | head -c 220)
  if [ -n "$out" ]; then echo "OK   $name :: $out"; else echo "FAIL $name :: $url"; fi
}
echo "--- Sui ---"
probe sui-fullnode "https://fullnode.mainnet.sui.io:443" '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'
probe sui-publicnode "https://sui-rpc.publicnode.com" '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'
echo "--- Starknet ---"
probe starknet-blast "https://starknet-mainnet.public.blastapi.io/rpc/v0_8" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-lava "https://rpc.starknet.lava.build" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-nethermind "https://free-rpc.nethermind.io/mainnet-juno/v0_8" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
echo "--- Radix ---"
probe radix-gw "https://mainnet.radixdlt.com/status/gateway-status" '{}'
echo "--- Injective LCD ---"
probe_get inj-lcd "https://lcd.injective.network/cosmos/base/tendermint/v1beta1/node_info"
probe_get inj-lcd2 "https://injective-rest.publicnode.com/cosmos/base/tendermint/v1beta1/node_info"
echo "--- Hedera ---"
probe hedera-hashio "https://mainnet.hashio.io/api" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
echo "--- Filecoin ---"
probe fil-glif "https://api.node.glif.io/rpc/v1" '{"jsonrpc":"2.0","id":1,"method":"Filecoin.ChainHead","params":[]}'
probe fil-another "https://filfox.info/rpc/v1" '{"jsonrpc":"2.0","id":1,"method":"Filecoin.ChainHead","params":[]}'
echo "--- Oasis Emerald ---"
probe oasis-1 "https://emerald.oasis.dev" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
probe oasis-2 "https://rpc.emerald.oasis.io" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
probe oasis-3 "https://emerald.oasis.io" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
echo "--- Acala/Karura substrate ---"
probe acala-0 "https://acala-rpc-0.aca-api.network" '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}'
probe acala-1 "https://acala-rpc-1.aca-api.network" '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}'
probe acala-pn "https://acala-rpc.publicnode.com" '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}'
probe karura-0 "https://karura-rpc-0.aca-api.network" '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}'
echo "--- ICON ---"
probe icon "https://ctz.solidwallet.io/api/v3" '{"jsonrpc":"2.0","id":1,"method":"icx_getLastBlock","params":{}}'
echo "--- Ergo ---"
probe_get ergo-info "https://api.ergoplatform.com/api/v1/info"
echo "--- Solana ---"
probe sol-main "https://api.mainnet-beta.solana.com" '{"jsonrpc":"2.0","id":1,"method":"getSlot","params":[]}'
probe sol-pn "https://solana-rpc.publicnode.com" '{"jsonrpc":"2.0","id":1,"method":"getSlot","params":[]}'
echo "--- Osmosis/Neutron/Secret LCD ---"
probe_get osmo-lcd "https://lcd.osmosis.zone/cosmos/base/tendermint/v1beta1/node_info"
probe_get osmo-pn "https://osmosis-rest.publicnode.com/cosmos/base/tendermint/v1beta1/node_info"
probe_get neutron-pn "https://lcd-neutron.publicnode.com/cosmos/base/tendermint/v1beta1/node_info"
probe_get neutron-official "https://rest-kralum.neutron-1.neutron.org/cosmos/base/tendermint/v1beta1/node_info"
probe_get secret-1 "https://lcd.secret.express/cosmos/base/tendermint/v1beta1/node_info"
probe_get secret-2 "https://secret-api.lavenderfive.com/cosmos/base/tendermint/v1beta1/node_info"
echo "--- Fiamma bridge API ---"
probe fiamma "https://bridge-api.fiammachain.io" '{"jsonrpc":"2.0","id":1,"method":"frontend_queryBridgeTVL","params":{}}'
echo "--- Ocean One API ---"
probe_get ocean-one "https://events.ocean.one/assets"
echo "--- HashMix API ---"
probe_get hashmix "https://fvm.hashmix.org/fevmapi/tvl"
echo "--- Shade API ---"
probe shade "https://prodv1.securesecrets.org/graphql" '{"operationName":"getLendHistory","variables":{"intervalIso":"2026-10-10T00:00:00.000Z"},"query":"query getLendHistory($intervalIso: String!) { lendStatsHistories(query: {where: {time: {gte: $intervalIso}}, orderBy: {time: \"desc\"}}) { collateralUsd debtUsd time } }"}'
