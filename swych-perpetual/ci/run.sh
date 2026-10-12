#!/usr/bin/env bash
# CI heavy job for swych-perpetual: order scan + event-window scan, using the keyed BSC RPC from env.
# Never prints or writes the RPC URL. Results -> ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
export BSC_RPC_URL="${BSC_RPC_URL:-https://bsc-rpc.publicnode.com}"
python3 ci/scan.py 2>&1 | tee ci-out/scan-console.log
echo "[run.sh] done"
