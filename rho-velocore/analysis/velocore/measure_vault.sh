#!/usr/bin/env bash
# Measure Velocore V2 vault token balances (the DefiLlama-style TVL) per chain.
set -u
DIR=/home/heisenberg/CA/rho-velocore/analysis/velocore/pools
measure() {
  chain=$1; R=$2; V=$3
  echo "chain,pool,token,balance"
  # unique tokens across all pools
  cat "$DIR/${chain}_pools.txt" | while read p; do
    timeout 20 cast call $p "listedTokens()(bytes32[])" --rpc-url $R 2>/dev/null | tr -d '[]' | tr ',' '\n' | sed 's/ //g'
  done | sort -u | while read t; do
    [ -z "$t" ] && continue
    addr=0x${t:26:40}
    if [ "$addr" = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" ]; then
      b=$(timeout 20 cast balance $V --rpc-url $R 2>/dev/null)
      echo "$chain,$V,NATIVE,$b"
    else
      b=$(timeout 20 cast call $addr "balanceOf(address)(uint256)" $V --rpc-url $R 2>/dev/null | head -1 | tr -d '\n')
      echo "$chain,$V,$addr,$b"
    fi
  done
}
measure linea https://rpc.linea.build 0x1d0188c4B276A09366D05d6Be06aF61a73bC7535 > "$DIR/linea_vault_balances.csv"
measure zksync https://mainnet.era.zksync.io 0xf5E67261CB357eDb6C7719fEFAFaaB280cB5E2A6 > "$DIR/zksync_vault_balances.csv"
measure telos https://rpc.telos.net 0x0117A9094c29e5A3D24ae608264Ce63B15b631d9 > "$DIR/telos_vault_balances.csv"
echo "== done =="
for c in linea zksync telos; do echo "--- $c"; awk -F, 'NR>1 && $4+0>0' "$DIR/${c}_vault_balances.csv" | head -20; done
