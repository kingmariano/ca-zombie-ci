#!/usr/bin/env bash
# FlareBank Phase-2 CI job: pick a working public Flare RPC, dump live state,
# run the exact-integer-math holder sell-out simulation. Read-only.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' -H 'User-Agent: Mozilla/5.0' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  echo ""; return 1
}

PICK=$(pick "${FLARE_RPC_URL:-}" \
  "https://flare-api.flare.network/ext/C/rpc" \
  "https://flare.rpc.thirdweb.com" \
  "https://flare-mainnet.public.blastapi.io" \
  "https://rpc.ftso.au/flare" || true)

if [ -z "$PICK" ]; then
  echo "ERROR: no working Flare RPC" | tee ci-out/error.txt
  exit 1
fi
echo "selected flare rpc (redacted): $(echo "$PICK" | sed -E 's#(https://[^/]+).*#\1/#')"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "FLARE_RPC_URL=$PICK" >> "$GITHUB_ENV"
fi
export FLARE_RPC_URL="$PICK"

python3 ci/sim.py "$PICK" 2>&1 | tee ci-out/sim.log
exit "${PIPESTATUS[0]}"
