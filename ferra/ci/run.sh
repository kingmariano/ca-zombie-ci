#!/usr/bin/env bash
# C2-53 Ferra DLMM — custom CI job. Read-only; public Sui endpoints only; no keys; no transactions.
# Writes proofs to ci-out/ (uploaded as artifacts).
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[ferra-ci] pwd=$(pwd)"
python3 --version
python3 analysis/ci_verify.py
RC=$?
echo "[ferra-ci] exit=$RC"
ls -la ci-out/ 2>/dev/null || true
exit $RC
