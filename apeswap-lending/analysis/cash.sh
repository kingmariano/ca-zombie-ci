#!/usr/bin/env bash
# Per-market getCash + token balances + USD prices (live).
source /home/heisenberg/CA/apeswap-lending/analysis/rpc.sh
CMP=0xad48b2c9dc6709a560018c678e918253a65df86e
OUT=/home/heisenberg/CA/apeswap-lending/analysis/cash.tsv
: > "$OUT"
printf 'symbol\ttoken\tgetCash\ttokenBalanceOf_cToken\ttotalSupply\ttotalBorrows\ttotalReserves\n' >> "$OUT"
MARKETS=$(C $CMP 'getAllMarkets()(address[])' | tr -d '[]' | tr ',' ' ')
for m in $MARKETS; do
  sym=$(C $m 'symbol()(string)' | tr -d '"')
  und=$(C $m 'underlying()(address)')
  gc=$(C $m 'getCash()(uint256)' 2>/dev/null || echo ERR)
  if [ "$und" = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" ]; then
    bal=$(cast balance --rpc-url "$BSC_RPC" "$m" 2>/dev/null || echo ERR)
  else
    bal=$(cast call --rpc-url "$BSC_RPC" "$und" 'balanceOf(address)(uint256)' "$m" 2>/dev/null || echo ERR)
  fi
  ts=$(C $m 'totalSupply()(uint256)')
  tb=$(C $m 'totalBorrows()(uint256)')
  tr=$(C $m 'totalReserves()(uint256)')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$sym" "$und" "$gc" "$bal" "$ts" "$tb" "$tr" >> "$OUT"
  printf '%s cash=%s bal=%s ts=%s tb=%s tr=%s\n' "$sym" "$gc" "$bal" "$ts" "$tb" "$tr"
done
cat "$OUT"
