#!/usr/bin/env bash
# Custom CI job for l2-triage-c (L-2 Phase-1 non-EVM custody screen).
# Read-only: queries chain-native public endpoints; no keys written anywhere.
set -uo pipefail
cd "$(dirname "$0")/.."    # l2-triage-c/
mkdir -p ci-out
set -o pipefail
python3 ci/scan.py 2>&1 | tee ci-out/scan.log
echo "[run.sh] scan.py exit=${PIPESTATUS[0]}"
ls -la ci-out/
