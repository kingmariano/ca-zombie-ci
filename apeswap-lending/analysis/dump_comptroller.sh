#!/usr/bin/env bash
# Dump ApeSwap Lending Comptroller state (read-only), block-pinned.
set -e
source /home/heisenberg/CA/apeswap-lending/analysis/rpc.sh
OUT=/home/heisenberg/CA/apeswap-lending/analysis/comptroller_dump
CMP=0xad48b2c9dc6709a560018c678e918253a65df86e
blk=$(B)
mkdir -p "$OUT"
{
  printf 'block=%s\n' "$blk"
  printf 'admin=%s\n' "$(C --block "$blk" $CMP 'admin()(address)')"
  printf 'pendingAdmin=%s\n' "$(C --block "$blk" $CMP 'pendingAdmin()(address)')"
  printf 'oracle=%s\n' "$(C --block "$blk" $CMP 'oracle()(address)')"
  printf 'closeFactor=%s\n' "$(C --block "$blk" $CMP 'closeFactorMantissa()(uint256)')"
  printf 'liquidationIncentive=%s\n' "$(C --block "$blk" $CMP 'liquidationIncentiveMantissa()(uint256)')"
  printf 'pauseGuardian=%s\n' "$(C --block "$blk" $CMP 'pauseGuardian()(address)')"
  printf 'transferGuardianPaused=%s\n' "$(C --block "$blk" $CMP 'transferGuardianPaused()(bool)')"
  printf 'seizeGuardianPaused=%s\n' "$(C --block "$blk" $CMP 'seizeGuardianPaused()(bool)')"
  printf 'allMarkets_raw=%s\n' "$(C --block "$blk" $CMP 'getAllMarkets()(address[])')"
} > "$OUT/comptroller.txt" 2>&1
cat "$OUT/comptroller.txt"
