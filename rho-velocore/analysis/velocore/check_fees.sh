#!/usr/bin/env bash
# Check fee1e9/feeMultiplier/totalSupply for every enumerated pool.
set -u
DIR=/home/heisenberg/CA/rho-velocore/analysis/velocore/pools
check() {
  chain=$1; R=$2; p=$3
  fee=$(timeout 20 cast call $p "fee1e9()(uint256)" --rpc-url $R 2>/dev/null | head -1 | tr -d '\n')
  fm=$(timeout 20 cast call $p "feeMultiplier()(uint256)" --rpc-url $R 2>/dev/null | head -1 | tr -d '\n')
  ts=$(timeout 20 cast call $p "totalSupply()(uint256)" --rpc-url $R 2>/dev/null | head -1 | tr -d '\n')
  lt=$(timeout 20 cast call $p "lastWithdrawTimestamp()(uint256)" --rpc-url $R 2>/dev/null | head -1 | tr -d '\n')
  echo "$chain,$p,$fee,$fm,$ts,$lt"
}
export -f check
for chain in linea zksync telos; do
  case $chain in linea) R=https://rpc.linea.build;; zksync) R=https://mainnet.era.zksync.io;; telos) R=https://rpc.telos.net;; esac
  echo "chain,pool,fee1e9,feeMultiplier,totalSupply,lastWithdrawTimestamp" > "$DIR/${chain}_fees.csv"
  cat "$DIR/${chain}_pools.txt" | xargs -P 6 -I{} bash -c "check $chain $R {}" >> "$DIR/${chain}_fees.csv"
done
echo "== non-zero fees =="
grep -v ",0," "$DIR"/*_fees.csv | grep -v "^chain," || echo "ALL ZERO"
echo "== summary =="
for chain in linea zksync telos; do echo "$chain total: $(( $(wc -l < $DIR/${chain}_fees.csv) - 1 ))"; done