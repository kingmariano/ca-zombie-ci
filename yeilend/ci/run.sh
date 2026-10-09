#!/usr/bin/env bash
# YeiLend (Sei) CI job: borrower health scan + endpoint failover for the Foundry fork tests.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "=== Sei RPC endpoint pick ==="
pick=""; label=""
probe() {
  r=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$1" 2>/dev/null)
  case "$r" in *result*) return 0;; *) return 1;; esac
}
if [ -n "${DRPC_API_KEY:-}" ] && probe "https://lb.drpc.org/ogrpc?network=sei&dkey=${DRPC_API_KEY}"; then
  pick="https://lb.drpc.org/ogrpc?network=sei&dkey=${DRPC_API_KEY}"; label="authenticated drpc"
fi
if [ -z "$pick" ]; then
  for u in "https://1329.rpc.thirdweb.com" "https://sei.drpc.org" "https://sei-evm-rpc.publicnode.com" "https://evm-rpc.sei-apis.com"; do
    if probe "$u"; then pick="$u"; label="$u"; break; fi
  done
fi
echo "picked: ${label:-none}"
if [ -n "$pick" ] && [ -n "${GITHUB_ENV:-}" ]; then
  echo "SEI_RPC_URL=$pick" >> "$GITHUB_ENV"
fi

if [ -f ci-out/SKIP_SCAN ]; then
  echo "SKIP_SCAN present; skipping borrower scan"
else
  python3 analysis/scan_all_users.py
fi
echo "=== scan artifacts ==="
ls -la ci-out/ || true
