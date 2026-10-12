#!/usr/bin/env bash
# Cap Finance v1-v3 — heavy job: run the fork PoC at a pinned Arbitrum block.
# Read-only. No secrets are written to files (keys only ever in env).
set -uo pipefail
cd "$(dirname "$0")/.."

BLOCK=513983151
mkdir -p ci-out

echo "[cap] start $(date -u +%FT%TZ)"
export PATH="$PATH:$HOME/.foundry/bin"

# probe candidate RPCs for archive support at the pinned block
probe() { # url
  local url="$1"
  local out
  out=$(timeout 25 cast call 0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e \
        "totalSupply()(uint256)" --block "$BLOCK" --rpc-url "$url" 2>/dev/null | head -1)
  case "$out" in
    12300224050079388373*) return 0 ;;
    *) return 1 ;;
  esac
}

CHOSEN=""
if [ -n "${ARB_RPC_URL:-}" ] && probe "$ARB_RPC_URL"; then CHOSEN="$ARB_RPC_URL"; fi
if [ -z "$CHOSEN" ] && [ -n "${ANKR_API_KEY:-}" ]; then
  U="https://rpc.ankr.com/arbitrum/${ANKR_API_KEY}"
  if probe "$U"; then CHOSEN="$U"; fi
fi
if [ -z "$CHOSEN" ] && [ -n "${DRPC_API_KEY:-}" ]; then
  U="https://lb.drpc.org/ogrpc?network=arbitrum&dkey=${DRPC_API_KEY}"
  if probe "$U"; then CHOSEN="$U"; fi
fi

if [ -z "$CHOSEN" ]; then
  echo "[cap] no archive RPC available; running tests at latest block"
  unset FORK_BLOCK FORK_RPC
else
  echo "[cap] archive RPC found; pinned block $BLOCK"
  export FORK_RPC="$CHOSEN"
  export FORK_BLOCK="$BLOCK"
fi

cd poc
forge test -vv 2>&1 | tee ../ci-out/forge-test.log
RC=${PIPESTATUS[0]}
cd ..
echo "[cap] forge test rc=$RC"
# summary
grep -E "Suite result|tests passed|\[PASS\]|\[FAIL\]" ci-out/forge-test.log | tail -30 || true
echo "[cap] end $(date -u +%FT%TZ)"
exit $RC
