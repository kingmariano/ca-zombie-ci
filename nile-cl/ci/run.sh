#!/usr/bin/env bash
# Nile CL (Linea) heavy CI job. Read-only. Results -> ci-out/.
# Never print keyed RPC URLs.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

echo "[nile-cl ci] starting heavy scan"
python3 - <<'PY'
import os
# sanity: which RPC kinds are available (no values printed)
print("env ALCHEMY:", bool(os.environ.get("ALCHEMY_API_KEY")),
      "DRPC:", bool(os.environ.get("DRPC_API_KEY")),
      "ANKR:", bool(os.environ.get("ANKR_API_KEY")))
PY

python3 ci/scan.py > ci-out/scan.log 2>&1
RC=$?
echo "[nile-cl ci] scan rc=$RC"
tail -c 4000 ci-out/scan.log
exit $RC
