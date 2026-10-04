#!/usr/bin/env bash
# H-22 CI job: read-only state verification for Serum v3 / OpenBook v1.
# Results land in ci-out/ and are uploaded as artifacts.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> serum/
mkdir -p ci-out
python3 analysis/ci_state_check.py > ci-out/state_check.log 2>&1
echo "exit=$?"
tail -5 ci-out/state_check.log || true
ls -la ci-out/
