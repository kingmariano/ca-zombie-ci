#!/usr/bin/env bash
# Augury Finance L2-P2 heavy enumeration job (runs in GitHub Actions).
# Read-only: RPC eth_calls only; no secrets printed; results in ci-out/.
set -uo pipefail

echo "[augury] starting heavy scan $(date -u +%FT%TZ)"
echo "[augury] rpc host: $(printf '%s' "${POLYGON_RPC_URL:-https://polygon-bor-rpc.publicnode.com}" | sed -E 's#https?://([^/]+).*#\1#')"

mkdir -p ci-out
python3 ci/scan.py
rc=$?
echo "[augury] scan exit=$rc"
echo "[augury] artifacts:"; ls -la ci-out || true
exit $rc
