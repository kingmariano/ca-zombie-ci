#!/usr/bin/env bash
# C2-51 Troves/STRKFarm retired vaults (Starknet) — CI proof job.
# Read-only: keyless public Starknet RPCs only; no keys, no transactions, no signing.
set -euo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out

python3 --version
echo "[ci] running consolidated proof suite (keyless RPCs; no secrets used)"

# Run from analysis/ so `import rpc` resolves; output to ../ci-out
cd analysis
python3 ci_proofs.py ../ci-out | tee ../ci-out/run_stdout.txt

echo "[ci] proofs.json:"; wc -c ../ci-out/proofs.json
echo "[ci] done"
