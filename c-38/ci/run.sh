#!/usr/bin/env bash
# C-38 heavy CI job: Tectonic (Cronos) live state + exact extractable liquidation profit.
set -uo pipefail
echo "[c-38] RPC env set: ${CRONOS_RPC_URL:+yes}"
python3 --version
mkdir -p ci-out
python3 ci/heavy_scan.py 2>&1 | tee ci-out/heavy_scan.log
echo "[c-38] results:"
ls -la ci-out/
