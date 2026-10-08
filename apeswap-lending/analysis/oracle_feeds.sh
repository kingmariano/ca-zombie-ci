#!/usr/bin/env bash
# Chainlink oracle feed dump for ApeSwap Lending (read-only).
source /home/heisenberg/CA/apeswap-lending/analysis/rpc.sh
ORC=0x7c37BF8dBd4Ae90cdf45d382cEB1580c5d9300CC
OUT=/home/heisenberg/CA/apeswap-lending/analysis/oracle_feeds.tsv
: > "$OUT"
printf 'underlying\tfeed\tfeedDecimals\tassetDecimals\trawPrice\tprice\ttimestamp\n' >> "$OUT"
for u in \
 0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95 \
 0x2170Ed0880ac9A755fd29B2688956BD959F933F8 \
 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56 \
 0x55d398326f99059fF775485246999027B3197955 \
 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82 \
 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d \
 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE \
 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c \
 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402 \
 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275; do
  feed=$(C $ORC 'chainLinkFeeds(address)(address)' $u 2>/dev/null || echo ERR)
  fd=$(C $ORC 'chainLinkFeedDecimals(address)(uint8)' $u 2>/dev/null || echo ERR)
  ad=$(C $ORC 'assetsDecimals(address)(uint8)' $u 2>/dev/null || echo ERR)
  if [ "$feed" != "ERR" ] && [ "$feed" != "0x0000000000000000000000000000000000000000" ]; then
    raw=$(C $ORC 'chainLinkRawReportedPrice(address)(int256)' $u 2>/dev/null | awk '{print $1}' || echo ERR)
    ts=$(C $ORC 'getAssetPriceUpdateTimestamp(address)(uint256)' $u 2>/dev/null | awk '{print $1}' || echo ERR)
  else
    raw=NA; ts=NA
  fi
  pr=$(C $ORC 'getAssetPrice(address)(uint256)' $u 2>/dev/null | awk '{print $1}' || echo ERR)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$u" "$feed" "$fd" "$ad" "$raw" "$pr" "$ts" >> "$OUT"
  printf '%s feed=%s raw=%s ts=%s price=%s\n' "$u" "$feed" "$raw" "$ts" "$pr"
done
cat "$OUT"
