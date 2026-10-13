#!/usr/bin/env bash
# =============================================================================
# Nerve QC-5 — adversarial re-audit custom CI job (read-only).
# Runs the QC fork suite + a fresh independent RPC state fingerprint.
# Nothing is signed or broadcast; all execution is on throwaway forks.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."   # -> nerve-qc/
mkdir -p ci-out

RPC="${BSC_RPC_URL:-https://bsc-rpc.publicnode.com}"

echo "== QC fork suite =="
( cd poc && BSC_RPC_URL="$RPC" forge test -vvv ) > ci-out/qc-forge.txt 2>&1
rc=$?
echo "forge exit code: $rc" | tee -a ci-out/qc-forge.txt
grep -E "\[PASS\]|\[FAIL\]|Suite result" ci-out/qc-forge.txt | tail -20 || true

echo "== independent state fingerprint =="
python3 analysis/ci_fingerprint.py > ci-out/ci-fingerprint.txt 2>&1 || true
tail -30 ci-out/ci-fingerprint.txt || true

echo "== ci-out =="
ls -la ci-out/
exit 0
