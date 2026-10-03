#!/usr/bin/env bash
# Bucket Farm (Sui, H-01) — read-only dry-run proof suite.
# Runs on the GitHub Actions runner (public CI repo). No secrets, no transactions.
set -uo pipefail
cd "$(dirname "$0")/.."    # bucket-farm/
mkdir -p ci-out

echo "=== Bucket Farm H-01 — read-only dry-run proofs ==="
date -u
node --version
npm --version

cd poc-node
if [ ! -d node_modules ]; then
  echo "[ci] installing @mysten/sui ..."
  npm i --no-audit --no-fund --silent @mysten/sui@1.30.0 || { echo "npm install failed"; exit 1; }
fi

echo "[ci] live state dump ..."
node statedump.js > ../ci-out/state.json 2> ../ci-out/statedump.err
echo "[ci] state.json bytes: $(wc -c < ../ci-out/state.json)"

echo "[ci] dry-run suite ..."
node dryruns.js all > ../ci-out/dryruns.txt 2>&1
cat ../ci-out/dryruns.txt

if grep -q '\[FAIL\]' ../ci-out/dryruns.txt; then
  echo "[ci] RESULT: FAIL (see above)"
  exit 1
fi
if ! grep -q '\[PASS\]' ../ci-out/dryruns.txt; then
  echo "[ci] RESULT: FAIL (no PASS lines)"
  exit 1
fi
echo "[ci] RESULT: ALL EXPECTATIONS MET"
