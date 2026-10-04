#!/usr/bin/env bash
# Enumerate Velocore V2 pools via canonicalPools on Linea/zkSync/Telos; check fee1e9 + balances.
set -u
SIG="canonicalPools(address,uint256,uint256)((address,(address,string,bytes32[],uint256[],bytes32[],uint256[],bytes),bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bytes32[],uint256[],uint256[],bytes32[],uint256[],uint256,(bytes32[],uint256[],uint256[],uint256[])[])[])"
mkdir -p /home/heisenberg/CA/rho-velocore/analysis/velocore/pools
enumerate() {
  name=$1; R=$2; F=$3
  echo "=== $name ($R) ==="
  out=$(timeout 60 cast call $F "$SIG" $F 0 200 --rpc-url $R 2>&1)
  echo "$out" > "/home/heisenberg/CA/rho-velocore/analysis/velocore/pools/${name}_canonical.txt"
  # extract pool addresses: pattern "0xADDR, \"cpmm\"" or gauge==pool; take all 0x... "cpmm" preceded addr
  echo "$out" | grep -oE '0x[0-9a-fA-F]{40}, "cpmm"' | cut -d, -f1 | sort -u > "/home/heisenberg/CA/rho-velocore/analysis/velocore/pools/${name}_pools.txt"
  echo "pools found: $(wc -l < /home/heisenberg/CA/rho-velocore/analysis/velocore/pools/${name}_pools.txt)"
}
enumerate linea https://rpc.linea.build 0xaA18cDb16a4DD88a59f4c2f45b5c91d009549e06
enumerate zksync https://mainnet.era.zksync.io 0xf55150000aac457eCC88b34dA9291e3F6E7DB165
enumerate telos https://rpc.telos.net 0x5123EE9A02b7435988D4B120633d045EF6a0159B
