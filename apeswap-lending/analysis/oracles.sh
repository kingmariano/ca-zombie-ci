#!/usr/bin/env bash
# For each market underlying: registry oracle + price + supply cap? (read-only)
source /home/heisenberg/CA/apeswap-lending/analysis/rpc.sh
CMP=0xad48b2c9dc6709a560018c678e918253a65df86e
REG=0xAE933Da5860559080F47e594504CE5445D86f78a
OUT=/home/heisenberg/CA/apeswap-lending/analysis/oracles.tsv
: > "$OUT"
printf 'symbol\tunderlying\toracle\tprice\n' >> "$OUT"
MARKETS=$(C $CMP 'getAllMarkets()(address[])' | tr -d '[]' | tr ',' ' ')
for m in $MARKETS; do
  sym=$(C $m 'symbol()(string)' | tr -d '"')
  und=$(C $m 'underlying()(address)')
  orc=$(C $REG 'getOracleForAsset(address)(address)' "$und")
  pr=$(C $REG 'getPriceForAsset(address)(uint256)' "$und")
  printf '%s\t%s\t%s\t%s\n' "$sym" "$und" "$orc" "$pr" >> "$OUT"
  printf '%s oracle=%s price=%s\n' "$sym" "$orc" "$pr"
done
cat "$OUT"
