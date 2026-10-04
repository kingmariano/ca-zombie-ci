#!/usr/bin/env bash
# H-25 GRXswap — custom CI job.
#   1. Recompile the verified GRXSwap TokenPair + GRXSwapFactoryV2 (solc 0.5.16, optimizer off)
#      and compare metadata-stripped runtime bytecode with the live deployments.
#   2. Dump a single-block (atomic) state snapshot of the whole deployment.
# Foundry fork tests then run via the workflow's `forge test -vvv` step (poc/).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
RPC="${GRX_RPC_URL:-https://rpc.grxchain.io}"
echo "[grxswap-ci] rpc=$RPC"
echo "[grxswap-ci] block=$(curl -s -m 20 -X POST "$RPC" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | head -c 200)"

# --- 1. bytecode verification (solc 0.5.16 profiles) ---
FOUNDRY_PROFILE=pair    forge build --root poc > ci-out/build-pair.log 2>&1 \
  && echo "[grxswap-ci] pair build OK" || echo "[grxswap-ci] pair build FAILED (see ci-out/build-pair.log)"
FOUNDRY_PROFILE=factory forge build --root poc > ci-out/build-factory.log 2>&1 \
  && echo "[grxswap-ci] factory build OK" || echo "[grxswap-ci] factory build FAILED (see ci-out/build-factory.log)"
python3 ci/verify_bytecode.py > ci-out/bytecode.json 2> ci-out/bytecode.err \
  && echo "[grxswap-ci] bytecode verification written" || echo "[grxswap-ci] bytecode verification FAILED"
cat ci-out/bytecode.json 2>/dev/null | head -60

# --- 2. atomic live-state dump ---
python3 ci/state_dump.py > ci-out/state.json 2> ci-out/state.err \
  && echo "[grxswap-ci] state dump written" || echo "[grxswap-ci] state dump FAILED"
python3 - <<'PY' 2>/dev/null || true
import json
d=json.load(open("ci-out/state.json"))
print("block", d.get("block"), "pairs", len(d.get("pair_state", [])))
for p in d.get("pair_state", []):
    print(" ", p.get("pair"), p.get("reserve0"), p.get("reserve1"), "bal", p.get("balance_token0"), p.get("balance_token1"))
PY
echo "[grxswap-ci] done"
exit 0
