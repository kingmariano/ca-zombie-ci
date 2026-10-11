#!/usr/bin/env bash
# Custom CI job for the hord finding: pinned-fork verification when archive state is
# available, otherwise latest-block fork (protocol state is frozen), plus persisted results.
# Runs from the finding folder root (working-directory: hord). No secrets are written.
set -uo pipefail

mkdir -p ci-out
RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
CANON=26170355

# Probe whether the RPC serves archive state at the canonical block.
ARCHIVE=no
PROBE="$(cast call 0x5bBe36152d3CD3eB7183A82470b39b29EedF068B "totalSupply()(uint256)" $BLKARG --rpc-url "$RPC" 2>/dev/null || true)"
case "$PROBE" in 0x*) ARCHIVE=yes;; esac

if [ "$ARCHIVE" = yes ]; then BLK="$CANON"; BLKARG="--block $CANON"; else BLK=0; BLKARG=""; fi

{
  echo "finding=hord"
  echo "date=$(date -u +%FT%TZ)"
  echo "rpc_source=ci-env (redacted)"
  echo "archive_at_canonical_block=$ARCHIVE"
  if [ "$BLK" = 0 ]; then
    echo "fork_block=latest (canonical snapshot 26170355 unavailable via archive RPC; state frozen)"
  else
    echo "fork_block=$CANON"
  fi
  echo "--- chain head on the fork RPC ---"
  cast block-number --rpc-url "$RPC" 2>&1 || true
  echo
  echo "--- live reads (read-only) ---"
  echo -n "hETH.totalSupply: "; cast call 0x5bBe36152d3CD3eB7183A82470b39b29EedF068B "totalSupply()(uint256)" $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo -n "SM.paused:        "; cast call 0x5bBe36152d3CD3eB7183A82470b39b29EedF068B "paused()(bool)" $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo -n "SM.balance:       "; cast balance 0x5bBe36152d3CD3eB7183A82470b39b29EedF068B $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo -n "WM.paused:        "; cast call 0x4FdC295580287b1e3C8fa8875f0fbDc688d8e8A5 "paused()(bool)" $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo -n "WM.balance:       "; cast balance 0x4FdC295580287b1e3C8fa8875f0fbDc688d8e8A5 $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo -n "WM.assuredClaims: "; cast call 0x4FdC295580287b1e3C8fa8875f0fbDc688d8e8A5 "assuredClaimsBalance()(uint256)" $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo -n "pod.balance:      "; cast balance 0xb1d6Eb8893e74fd42BFd48A1007aA3F3ec064EE0 $BLKARG --rpc-url "$RPC" 2>&1 || true
  echo
  echo "--- forge test (FORK_BLOCK=$BLK) ---"
} > ci-out/ci-summary.txt

cd poc || exit 1
FORK_BLOCK="$BLK" FORK_RPC_URL="$RPC" forge test -vvv >> ../ci-out/ci-summary.txt 2>&1
RC=$?
echo "forge_exit=$RC" >> ../ci-out/ci-summary.txt
grep -E "^\[(PASS|FAIL)\]|^Suite result|^Ran [0-9]+ test suite" ../ci-out/ci-summary.txt > ../ci-out/test-results.txt 2>/dev/null || true
exit "$RC"
