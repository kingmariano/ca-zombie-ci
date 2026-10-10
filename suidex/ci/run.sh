#!/usr/bin/env bash
# C2-52 SuiDex heavy verification job (read-only, keyless public endpoints only).
# 1) full live-state scans + reconciliation + H-O/S split (python, endpoint-rotating)
# 2) devInspect attacker/positive battery (node, @mysten/sui v1, endpoint-rotating)
# All evidence -> ci-out/ (uploaded as artifacts). Job fails if any expectation breaks.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
export SUIDEX_RPC_SLEEP="${SUIDEX_RPC_SLEEP:-0.12}"

echo "=== [env] ==="
python3 --version
node --version || true

echo "=== [rpc] pick a working public Sui JSON-RPC (rotation list is used by the scripts) ==="
pick=""
for u in "https://sui-rpc.publicnode.com" "https://rpc-mainnet.suiscan.xyz" "https://sui.blockpi.network/v1/rpc/public" "https://1rpc.io/sui"; do
  r=$(curl -s -m 15 -X POST "$u" -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' 2>/dev/null)
  case "$r" in *result*) pick="$u"; break;; esac
done
if [ -z "$pick" ]; then echo "ERROR: no working Sui RPC"; exit 1; fi
echo "picked: $pick"
export SUI_RPC_URL="$pick"

echo "=== [1/2] live state scan + reconciliation + H-O split ==="
export SUIDEX_OUT_DIR="$PWD/ci-out"
python3 ci/ci_verify.py 2>&1 | tee ci-out/ci_verify.log

echo "=== [2/2] devInspect battery (dry-run, no tx sent) ==="
WORK="$(mktemp -d)"
cd "$WORK"
npm init -y >/dev/null 2>&1
npm install @mysten/sui@1 --no-audit --no-fund >/dev/null 2>&1
cp "$OLDPWD/analysis/devinspect_tests.mjs" .
SUI_RPC_URL="$pick" SUIDEX_DATA_DIR="$OLDPWD/ci-out" SUIDEX_OUT="$OLDPWD/ci-out/devinspect_results.json" \
  node devinspect_tests.mjs 2>&1 | tee "$OLDPWD/ci-out/devinspect.log"

echo "=== outputs ==="
ls -la "$OLDPWD/ci-out/"
