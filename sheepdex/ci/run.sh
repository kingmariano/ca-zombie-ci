#!/usr/bin/env bash
# sheepdex CI: start a local anvil forked from BSC at a slightly-pinned block (dodges
# load-balanced RPC replicas that lag at "latest"), and export LOCAL_FORK_URL so the
# subsequent `forge test -vvv` step forks from the stable local snapshot.
# Read-only: anvil only reads upstream state; no transactions are sent to BSC.
set -uo pipefail

mkdir -p ../ci-out
date -u +"anvil-prep %FT%TZ" > ../ci-out/anvil-start.txt

if [ -z "${BSC_RPC_URL:-}" ]; then
  echo "no BSC_RPC_URL set; skipping anvil (tests will fall back to public RPC)"
  exit 0
fi

BLK=$(cast block-number --rpc-url "$BSC_RPC_URL" 2>/dev/null || true)
echo "upstream latest block: ${BLK:-unknown}"
PIN_ARGS=()
if [ -n "$BLK" ] && [ "$BLK" -gt 200 ] 2>/dev/null; then
  PIN=$((BLK - 100))
  PIN_ARGS=(--fork-block-number "$PIN")
  echo "pinning fork block: $PIN"
fi

nohup anvil --port 8545 --host 127.0.0.1 --chain-id 56 --silent \
  --fork-url "$BSC_RPC_URL" "${PIN_ARGS[@]}" > anvil.log 2>&1 &
ANVIL_PID=$!
echo "anvil pid $ANVIL_PID"

READY=0
for _ in $(seq 1 60); do
  if cast block-number --rpc-url http://127.0.0.1:8545 >/dev/null 2>&1; then READY=1; break; fi
  sleep 2
done
if [ "$READY" = "1" ]; then
  LOCAL_BLK=$(cast block-number --rpc-url http://127.0.0.1:8545 2>/dev/null || echo "?")
  echo "anvil ready at block $LOCAL_BLK"
  echo "$LOCAL_BLK" > ../ci-out/anvil-block.txt
  if [ -n "${GITHUB_ENV:-}" ]; then
    echo "LOCAL_FORK_URL=http://127.0.0.1:8545" >> "$GITHUB_ENV"
    echo "exported LOCAL_FORK_URL for subsequent steps"
  fi
else
  echo "anvil failed to become ready; tests will use BSC_RPC_URL"
  tail -5 anvil.log || true
fi
