#!/usr/bin/env bash
# Custom CI job for the Ironclad Finance (Mode) deep dive.
# Read-only: selects a working Mode RPC, snapshots live state, and probes the
# full unprivileged attack surface with eth_call. Writes results to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  return 1
}

MODE=$(pick "https://mainnet.mode.network" "https://mode.drpc.org" "https://rpc-mode-mainnet-0.t.conduit.xyz" || true)
if [ -n "${MODE:-}" ]; then
  echo "MODE_RPC_URL=$MODE" >> "${GITHUB_ENV:-/dev/null}"
  echo "[ci] MODE_RPC_URL selected: $MODE"
else
  echo "[ci] WARNING: no Mode RPC reachable; using public default"
fi
export MODE_RPC_URL="${MODE:-https://mainnet.mode.network}"

pip3 install --quiet --disable-pip-version-check "eth-hash[pycryptodome]" eth-abi eth-utils requests >/dev/null 2>&1 || true

python3 ci/probe_surface.py > ci-out/probe_surface.log 2>&1 || echo "[ci] probe_surface failed"
python3 analysis/dump_state.py > ci-out/state_dump.log 2>&1 || echo "[ci] dump_state failed"
cp analysis/state_dump.json ci-out/state_dump.json 2>/dev/null || true
cp ci-out/probe_results.json ci-out/probe_results.json 2>/dev/null || true
echo "[ci] done"
ls -la ci-out
