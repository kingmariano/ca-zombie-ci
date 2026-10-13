#!/usr/bin/env bash
# Custom heavy job for mycelium-perpetual-swaps: dump live state to ci-out/ (public RPC only).
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out
python3 ci/dump-state.py > ci-out/live-state.log 2>&1 || echo "dump-state failed" >> ci-out/live-state.log
tail -c 4000 ci-out/live-state.log
