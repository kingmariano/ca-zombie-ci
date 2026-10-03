#!/usr/bin/env bash
# C-41 custom CI job:
#  1) pick a working Mode RPC and export it (MODE_RPC_URL) for the forge-test step
#  2) independent read-only state dumps for all 5 Ionic comptrollers into ci-out/
# Never fails the workflow: the authoritative gate is the forge fork-test step.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 0
mkdir -p ci-out
LOG=ci-out/enumerate.log
: > "$LOG"

echo "== C-41 custom job $(date -u +%FT%TZ) ==" >> "$LOG"

# CI secrets can arrive quoted; strip quotes from the dRPC key before use.
DK=$(printf '%s' "${DRPC_API_KEY:-}" | tr -d '"' | tr -d "'")
export DRPC_API_KEY="$DK"

# --- 1. pick Mode RPC (public first; dRPC fallback). Never echo the URL (may carry a key).
pick() {
  for u in "https://mainnet.mode.network" "https://lb.drpc.org/ogrpc?network=mode&dkey=${DRPC_API_KEY:-}"; do
    case "$u" in *"dkey=") continue ;; esac
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) printf '%s' "$u"; return 0 ;; esac
  done
  return 1
}
MODE_URL=$(pick || true)
if [ -n "$MODE_URL" ]; then
  echo "Mode RPC probe: OK" >> "$LOG"
  if [ -n "${GITHUB_ENV:-}" ]; then echo "MODE_RPC_URL=$MODE_URL" >> "$GITHUB_ENV"; fi
else
  echo "Mode RPC probe: none worked" >> "$LOG"
fi

# --- 2. state dumps (best effort; keyless public RPCs for reliability)
echo "quick_markets (public RPCs)" >> "$LOG"
python3 -m pip install --quiet --disable-pip-version-check eth-abi eth-utils "eth-hash[pycryptodome]" >> "$LOG" 2>&1 || true
run_one() {
  local chain="$1" comptroller="$2" out="$3"
  echo "--- $chain $comptroller -> $out" >> "$LOG"
  DRPC_API_KEY= IONIC_RPC_URL= python3 analysis/quick_markets.py \
    "$chain" "$comptroller" 0x9E34d89C013Da3BF65fc02b59B6F27D710850430 \
    --out "ci-out/$out" >> "$LOG" 2>&1
  echo "exit=$?" >> "$LOG"
}

run_one mode 0xfb3323e24743caf4add0fdccfb268565c0685556 mode_a_markets.json
run_one mode 0x8fb3d4a94d0aa5d6edaac3ed82b59a27f56d923a mode_b_markets.json
run_one base 0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13 base_markets.json
run_one op   0xaFB4A254D125B0395610fdc8f1D022936c7b166B op_markets.json
run_one lisk 0xF448A36feFb223B8E46e36FF12091baBa97bdF60 lisk_markets.json

echo "== done $(date -u +%FT%TZ) ==" >> "$LOG"
exit 0
