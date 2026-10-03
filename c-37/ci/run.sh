#!/usr/bin/env bash
# C-37 custom heavy job: Compound-fork empty-market scan (Rari Fuse + dForce) on Ethereum mainnet.
# Read-only. Writes results to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."

RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
mkdir -p ci-out
echo "[scan] starting at $(date -u +%FT%TZ)"
python3 ci/scan.py "$RPC" 2>&1 | tee ci-out/scan_stdout.txt | tail -n 60
echo "[scan] done at $(date -u +%FT%TZ)"
ls -la ci-out/
