#!/usr/bin/env bash
# Custom CI job for the Armada deep-dive. Read-only chain queries + simulateTransaction only.
set -uo pipefail
cd "$(dirname "$0")/.."    # armada/
mkdir -p ci-out
python3 ci/verify.py 2>&1 | tee ci-out/verify.log
echo "[run.sh] verify.py exit=${PIPESTATUS[0]}"
ls -la ci-out/
