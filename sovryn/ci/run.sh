#!/usr/bin/env bash
# H2-01 custom CI job — read-only evidence collection on RSK mainnet.
#   1. Replays the first Oct-2022 exploit tx (pre-fix) via `cast run` (fork of archive state).
#   2. Dumps the current on-chain state (targets, balances) to ci-out/.
# No mainnet transactions are sent; no secrets are used (keyless public RPC).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
mkdir -p ci-out
RPC="${RSK_RPC_URL:-https://public-node.rsk.co}"
echo "[ci] folder: $HERE"
echo "[ci] RSK RPC: keyless public endpoint (no secrets in logs)"

# 1) Historical replay of the first Oct-2022 exploit tx (iUSDT cycles)
echo "[ci] replaying Oct-2022 exploit tx 0xf5ea6266..."
if timeout 1500 cast run 0xf5ea6266a56f4e0135b73f63050afca7146bc940ac73da8b5fade9d8031582e2 \
    --fork-url "$RPC" --quick > ci-out/oct2022_exploit_replay.txt 2>&1; then
  echo "[ci] replay ok"
else
  echo "[ci] replay exit=$?"
fi

{
  echo "mint_events=$(grep -c 'emit Mint' ci-out/oct2022_exploit_replay.txt || true)"
  echo "burn_events=$(grep -c 'emit Burn' ci-out/oct2022_exploit_replay.txt || true)"
  echo "tx_success_lines=$(grep -c 'Transaction successfully executed' ci-out/oct2022_exploit_replay.txt || true)"
  echo "--- first mint/burn pairs (stale-price cycle) ---"
  grep -E 'emit (Mint|Burn)' ci-out/oct2022_exploit_replay.txt | head -6
} > ci-out/oct2022_summary.txt

# 2) Current state dump (targets + balances)
echo "[ci] dumping current state..."
python3 ci/dump_state.py "$RPC" > ci-out/state_dump.json 2> ci-out/state_dump.err \
  || echo "[ci] state dump failed (see state_dump.err)"

echo "[ci] done"
