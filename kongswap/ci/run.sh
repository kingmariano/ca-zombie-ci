#!/usr/bin/env bash
# KongSwap (ICP) CI job - READ-ONLY live-state audit via anonymous IC query calls.
# No transactions, no secrets. Outputs go to ci-out/ (uploaded as CI artifacts).
set -uo pipefail

echo "=== KongSwap ICP audit CI ==="
python3 --version
pip3 install --quiet --disable-pip-version-check ic-py cbor2 2>&1 | tail -2 || true
python3 -c "import ic, cbor2; print('ic-py ok')"

mkdir -p ci-out
python3 ci/icp_audit.py
RC=$?
echo "audit exit code: $RC"
ls -la ci-out/
exit $RC
