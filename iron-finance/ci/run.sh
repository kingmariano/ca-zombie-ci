#!/usr/bin/env bash
# Custom CI job for iron-finance:
#  1. pick a fork-viable RPC per chain (writes poc/rpc-*.txt, public-safe: "ENV" or a keyless URL)
#  2. dump live state to ci-out/state.json
# Uses CI-injected RPC env vars; falls back to keyless public endpoints.
set -euo pipefail
python3 ci/pick_rpc.py POLYGON_RPC_URL poc/rpc-polygon.txt \
    https://polygon-bor-rpc.publicnode.com https://polygon-rpc.com https://rpc.ankr.com/polygon || true
python3 ci/pick_rpc.py FANTOM_RPC_URL poc/rpc-fantom.txt \
    https://rpcapi.fantom.network https://fantom.drpc.org || true
python3 ci/dump_state.py
echo "--- ci-out/state.json (head) ---"
head -c 1200 ci-out/state.json
echo
