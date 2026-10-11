#!/usr/bin/env bash
probe() { local name="$1" url="$2" data="$3"; local out; out=$(curl -s -m 15 -X POST -H 'Content-Type: application/json' --data "$data" "$url" 2>/dev/null | head -c 200); if [ -n "$out" ]; then echo "OK   $name :: $out"; else echo "FAIL $name :: $url"; fi; }
probe_get() { local name="$1" url="$2"; local out; out=$(curl -s -m 15 "$url" -H 'User-Agent: Mozilla/5.0' 2>/dev/null | head -c 200); if [ -n "$out" ]; then echo "OK   $name :: $out"; else echo "FAIL $name :: $url"; fi; }
echo "--- Starknet alt ---"
probe starknet-cartridge "https://api.cartridge.gg/x/starknet/mainnet" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-1rpc "https://1rpc.io/starknet" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-drpc "https://starknet.drpc.org" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-nm2 "https://free-rpc.nethermind.io/mainnet-juno" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-nm3 "https://free-rpc.nethermind.io/mainnet-juno/v0_7" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
probe starknet-alchemy-demo "https://starknet-mainnet.g.alchemy.com/v2/demo" '{"jsonrpc":"2.0","id":1,"method":"starknet_blockNumber","params":[]}'
echo "--- Neutron alt ---"
probe_get neutron-polkachu "https://neutron-api.polkachu.com/cosmos/base/tendermint/v1beta1/node_info"
probe_get neutron-pn2 "https://neutron-rest.publicnode.com/cosmos/base/tendermint/v1beta1/node_info"
probe_get neutron-archival "https://rest.neutron.org/cosmos/base/tendermint/v1beta1/node_info"
probe_get neutron-kingnodes "https://neutron-rest.kingnodes.com/cosmos/base/tendermint/v1beta1/node_info"
echo "--- Secret alt ---"
probe_get secret-rest "https://rest.secret.express/cosmos/base/tendermint/v1beta1/node_info"
probe_get secret-pn "https://secret-rest.publicnode.com/cosmos/base/tendermint/v1beta1/node_info"
probe_get secret-lav "https://rest.lavenderfive.com/secret/cosmos/base/tendermint/v1beta1/node_info"
probe_get secret-polka "https://secret-api.polkachu.com/cosmos/base/tendermint/v1beta1/node_info"
echo "--- ICON retry ---"
probe icon2 "https://ctz.solidwallet.io/api/v3" '{"jsonrpc":"2.0","id":1,"method":"icx_getLastBlock","params":{}}'
probe_get icon3 "https://ctz.solidwallet.io/api/v3/status"
probe icon4 "https://api.icon.community/api/v3" '{"jsonrpc":"2.0","id":1,"method":"icx_getLastBlock","params":{}}'
echo "--- Fiamma variants ---"
probe_get fiamma2 "https://bridge-api.fiammachain.io/"
probe fiamma3 "https://bridge-api.fiammachain.io" '{"jsonrpc":"2.0","id":1,"method":"frontend_queryBridgeTVL","params":{}}'
dig +short bridge-api.fiammachain.io 2>/dev/null | head -3
echo "--- Shade variants ---"
probe shade2 "https://prodv1.securesecrets.org/graphql" '{"query":"{ __typename }"}'
dig +short prodv1.securesecrets.org 2>/dev/null | head -3
echo "--- Moria rostrum DNS ---"
dig +short rostrum.moria.money 2>/dev/null | head -3
echo "--- BCH fulcrum reachability (TCP) ---"
timeout 8 bash -c 'exec 3<>/dev/tcp/bch.imaginary.cash/50002 && echo "OK bch.imaginary.cash:50002 TCP"' 2>/dev/null || echo "FAIL bch.imaginary.cash:50002"
timeout 8 bash -c 'exec 3<>/dev/tcp/electroncash.de/50002 && echo "OK electroncash.de:50002 TCP"' 2>/dev/null || echo "FAIL electroncash.de:50002"
echo "--- Mixin API ---"
probe_get mixin-api "https://api.mixin.one/network/chains"
probe_get mixin-zeromesh "https://mixin-api.zeromesh.net/network/chains"
echo "--- Oasis explorer (Emerald) ---"
probe_get oasis-explorer "https://explorer.emerald.oasis.io/api/eth-rpc"
echo "--- Cardano Koios ---"
probe_get koios-tip "https://api.koios.rest/api/v1/tip"
echo "--- Sui GraphQL ---"
probe_get sui-graphql "https://graphql.mainnet.sui.io/graphql?query=%7B%20chainIdentifier%20%7D"
