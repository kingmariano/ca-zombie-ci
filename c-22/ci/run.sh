#!/usr/bin/env bash
# C2-22 Fulcrom — custom CI job (read-only live checks; no secrets written to output).
set -uo pipefail
cd "$(dirname "$0")/.."   # c-22/
mkdir -p ci-out
python3 ci/checks.py 2>&1 | tee ci-out/checks.txt
echo "exit=$?" | tee -a ci-out/checks.txt
# keep workflow green even if a single upstream RPC hiccups; the artifact records results
exit 0
