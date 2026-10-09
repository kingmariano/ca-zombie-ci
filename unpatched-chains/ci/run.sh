#!/usr/bin/env bash
# C2-26 unpatched-chains — CI verification job (read-only, public endpoints only).
# Outputs to ci-out/. Never prints or writes secrets.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "=== C2-26 unpatched-chains verification $(date -u +%FT%TZ) ===" | tee ci-out/runner.log
python3 ci/verify.py 2>&1 | tee -a ci-out/runner.log
rc=${PIPESTATUS[0]}
echo "=== verify.py exit: $rc ===" | tee -a ci-out/runner.log
ls -la ci-out/ | tee -a ci-out/runner.log
exit $rc
