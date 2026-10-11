#!/usr/bin/env bash
# CI heavy job for cover-protocol: dump live state at the pinned block into ci-out/.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
python3 ci/dump_state.py
echo "ci-out/:"; ls -la ci-out/
