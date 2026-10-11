#!/usr/bin/env bash
# =============================================================================
# Nerve (NerveNetwork / NerveSwap, BSC) — Phase-2 custom CI job
# =============================================================================
# 1) probes candidate BSC RPCs for ARCHIVE support (needed for the pre-exploit
#    historical fork test at block 12,653,564),
# 2) if an archive RPC is found, runs the historical fork tests
#    (NerveHistoricalTest) pinned one block before the Nov-14-2021 exploit tx,
# 3) records everything under ci-out/.
#
# Read-only: all tests execute on throwaway forks; nothing is broadcast.
# No secrets are written to disk: only probe *results* are recorded.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."   # -> nerve/
mkdir -p ci-out

IMPL="0xf642f2a626a8b732619606c493abfc2433dd2d35"
HIST_BLOCK=12653564

# candidate RPCs (constructed at runtime from CI env vars; never persisted)
CANDIDATES=()
[[ -n "${BSC_RPC_URL:-}" ]] && CANDIDATES+=("$BSC_RPC_URL")
[[ -n "${ANKR_API_KEY:-}" ]] && CANDIDATES+=("https://rpc.ankr.com/bsc/${ANKR_API_KEY}")
[[ -n "${NODEREAL_API_KEY:-}" ]] && CANDIDATES+=("https://bsc-mainnet.nodereal.io/v1/${NODEREAL_API_KEY}")
CANDIDATES+=("https://bsc-rpc.publicnode.com")

ARCHIVE_RPC=""
: > ci-out/archive-probe.txt
for u in "${CANDIDATES[@]}"; do
  host="$(echo "$u" | sed -E 's#(https://[^/]+).*#\1#')"
  out="$(cast code --rpc-url "$u" --block "$HIST_BLOCK" "$IMPL" 2>&1 | head -c 60 || true)"
  if [[ "$out" == 0x60806040* ]]; then
    echo "archive OK via ${host}" | tee -a ci-out/archive-probe.txt
    ARCHIVE_RPC="$u"
    break
  else
    echo "no archive via ${host} (${out:0:40})" | tee -a ci-out/archive-probe.txt
  fi
done

if [[ -n "$ARCHIVE_RPC" ]]; then
  echo "== historical fork tests =="
  ( cd poc && HIST_RPC="$ARCHIVE_RPC" BSC_RPC_URL="$ARCHIVE_RPC" \
      forge test --match-contract NerveHistoricalTest -vvv ) > ci-out/historical-fork.txt 2>&1
  echo "historical test exit code: $?" | tee -a ci-out/historical-fork.txt
  grep -E "Suite result|PASS|FAIL" ci-out/historical-fork.txt | tail -10 || true
else
  echo "historical fork tests skipped (no archive RPC)" > ci-out/historical-fork.txt
fi

# quick live snapshot for the record (current block only)
( cd poc && forge test --match-test test_live_state_snapshot -vvv ) > ci-out/live-snapshot.txt 2>&1 || true
echo "== ci-out =="
ls -la ci-out/
exit 0
