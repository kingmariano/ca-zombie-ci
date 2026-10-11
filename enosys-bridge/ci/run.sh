#!/usr/bin/env bash
# CI heavy job for enosys-bridge: live-state re-verification on Ethereum, XDC,
# Songbird and Flare. Public keyless RPCs only; results to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out
python3 ci/live_state.py || echo "live_state.py failed" >&2
echo "--- ci-out ---"
ls -la ci-out/
