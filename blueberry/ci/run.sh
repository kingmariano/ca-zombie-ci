#!/usr/bin/env bash
# Blueberry CI heavy job: Monad fork PoC + live state dump (read-only).
# Runs from the finding folder root (blueberry/). Public RPCs only.
set -uo pipefail

echo "=== [1/2] Monad fork tests (public RPC, no keys) ==="
if [ -d poc-monad ]; then
  ( cd poc-monad && forge test -vvv --rpc-url https://rpc.monad.xyz ) 2>&1 | tee ci-out/monad-tests.log
  MONAD_RC=${PIPESTATUS[0]}
else
  echo "poc-monad missing"; MONAD_RC=1
fi

echo
echo "=== [2/2] live state dump ==="
python3 ci/state_dump.py 2>&1 | tee ci-out/state-dump.log
DUMP_RC=${PIPESTATUS[0]}

echo
echo "monad_tests_rc=$MONAD_RC state_dump_rc=$DUMP_RC"
if [ "$MONAD_RC" -ne 0 ] || [ "$DUMP_RC" -ne 0 ]; then
  exit 1
fi
exit 0
