#!/usr/bin/env bash
# Swerve LP token + event history probes (read-only). Uses ETHERSCANV2_API_KEY from env only.
set -u
RPC="${RPC:-https://ethereum-rpc.publicnode.com}"
P=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
LP=0x77c6e4a580c0dce4e5c7a17d0bc077188a83a059
echo "== LP token basic =="
for fn in "name()(string)" "symbol()(string)" "decimals()(uint256)" "totalSupply()(uint256)" "minter()(address)" "owner()(address)"; do
  printf "%-24s %s\n" "$fn" "$(cast call $LP "$fn" --rpc-url $RPC 2>&1 | head -1)"
done
echo "== LP token code size =="
cast code $LP --rpc-url $RPC | wc -c
echo "== pool code size =="
cast code $P --rpc-url $RPC | wc -c
echo "== event topic hashes =="
cast keccak "NewAdmin(address)"
cast keccak "CommitNewAdmin(uint256,address)"
cast keccak "TokenExchange(address,int128,uint256,int128,uint256)"
cast keccak "AddLiquidity(address,uint256[4],uint256[4],uint256,uint256)"
cast keccak "RemoveLiquidity(address,uint256[4],uint256[4],uint256)"
