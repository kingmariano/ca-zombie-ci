#!/usr/bin/env bash
# Measure live token balances of every Velocore V2 pool (Linea/zkSync/Telos).
set -u
DIR=/home/heisenberg/CA/rho-velocore/analysis/velocore/pools
bal() {
  chain=$1; R=$2; pool=$3
  # listed tokens
  toks=$(timeout 20 cast call $pool "listedTokens()(bytes32[])" --rpc-url $R 2>/dev/null | tr -d '[]' | tr ',' ' ')
  out=""
  for t in $toks; do
    addr=0x${t:26:40}
    if [ "$addr" = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" ]; then
      b=$(timeout 20 cast balance $pool --rpc-url $R 2>/dev/null)
      out="$out;ETH:$b"
    else
      b=$(timeout 20 cast call $addr "balanceOf(address)(uint256)" $pool --rpc-url $R 2>/dev/null | head -1 | tr -d '\n')
      out="$out;$addr:$b"
    fi
  done
  echo "$chain,$pool$out"
}
export -f bal
for chain in linea zksync telos; do
  case $chain in linea) R=https://rpc.linea.build;; zksync) R=https://mainnet.era.zksync.io;; telos) R=https://rpc.telos.net;; esac
  echo "chain,pool,balances" > "$DIR/${chain}_balances.csv"
  cat "$DIR/${chain}_pools.txt" | xargs -P 5 -I{} bash -c "bal $chain $R {}" >> "$DIR/${chain}_balances.csv"
  echo "$chain done: $(wc -l < $DIR/${chain}_balances.csv) rows"
done
