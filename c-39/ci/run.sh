#!/usr/bin/env bash
# C-39 custom heavy job: full PulseX V1+V2 pair skim scan on PulseChain.
# Runs in GitHub Actions (public repo). Read-only: eth_call only, no transactions.
set -uo pipefail

cd "$(dirname "$0")/.."   # c-39/
mkdir -p ci-out

echo "== env =="
python3 --version
df -h / | tail -1

# --- pick a working PulseChain RPC and export it for the Foundry tests ---
pick_rpc() {
  for u in "https://pulsechain-rpc.publicnode.com" "https://rpc.pulsechain.com" "https://rpc-pulsechain.g4mm4.io"; do
    r=$(curl -s -m 15 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  return 1
}
PULSE_RPC=$(pick_rpc || true)
if [ -z "$PULSE_RPC" ]; then
  echo "ERROR: no working PulseChain RPC"
  exit 1
fi
echo "PulseChain RPC selected"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "PULSECHAIN_RPC=$PULSE_RPC" >> "$GITHUB_ENV"
fi
export PULSECHAIN_RPC="$PULSE_RPC"

# --- full scan of every pair deployed by both factories (reuse a complete cached scan if present) ---
echo "== full skim scan (all pairs, pinned block) =="
SCAN_COMPLETE=0
if [ -f ci-out/skim_scan_full.json ]; then
  SCAN_COMPLETE=$(python3 - <<'PY'
import json
try:
    d = json.load(open("ci-out/skim_scan_full.json"))
    print(1 if d.get("stats", {}).get("pairs_total", 0) > 200000 else 0)
except Exception:
    print(0)
PY
)
fi
if [ "$SCAN_COMPLETE" = "1" ]; then
  echo "complete cached scan found (pairs_total > 200000) — skipping rescan"
else
  MC3_BATCH="${MC3_BATCH:-400}" timeout 9000 python3 ci/full_skim_scan.py \
    > ci-out/full_skim_scan.log 2>&1
  SCAN_RC=$?
  echo "scan rc=$SCAN_RC"
  tail -40 ci-out/full_skim_scan.log || true
fi

# --- price the flagged excess pairs (DefiLlama + on-chain symbols) ---
if [ -f ci-out/skim_scan_full.json ]; then
  python3 ci/price_flagged.py > ci-out/price_flagged.log 2>&1 || true
  tail -30 ci-out/price_flagged.log || true
fi

echo "== ci-out =="
ls -la ci-out/
exit 0
