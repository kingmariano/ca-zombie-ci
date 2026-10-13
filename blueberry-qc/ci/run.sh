#!/usr/bin/env bash
# Blueberry QC-4 CI job: Monad fork adversarial re-audit tests (read-only).
# Public RPC only; no keys, no transactions.
set -uo pipefail

mkdir -p ci-out

echo "=== [1/1] Monad fork QC counter-tests ==="
(
  cd poc-monad || exit 1
  forge test -vvv --rpc-url "${MONAD_RPC_URL:-https://rpc.monad.xyz}"
) 2>&1 | tee ci-out/monad-qc-tests.log
RC=${PIPESTATUS[0]}

echo
echo "monad_qc_tests_rc=$RC"
exit "$RC"
