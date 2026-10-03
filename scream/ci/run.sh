#!/usr/bin/env bash
# H-08 · Scream (Fantom) custom CI job — read-only live scan.
# Picks a working Fantom RPC, writes it to poc/rpc.txt for the Foundry fork tests,
# then dumps the full 27-market + oracle state into ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> scream/
mkdir -p ci-out

python3 ci/scan.py 2>&1 | tee ci-out/scan.log || echo "scan failed (continuing to forge tests)"

# choose RPC for the fork tests (env first, then public)
RPC=""
for u in "${FANTOM_RPC_URL:-}" "https://rpcapi.fantom.network" "https://fantom.api.onfinality.io/public" "https://fantom.drpc.org"; do
  [ -z "$u" ] && continue
  r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
  case "$r" in *result*) RPC="$u"; break;; esac
done
if [ -n "$RPC" ]; then
  printf '%s\n' "$RPC" > poc/rpc.txt
  echo "[ci] fork RPC written to poc/rpc.txt"
else
  echo "[ci] WARNING: no Fantom RPC found; poc/rpc.txt left as-is"
fi
