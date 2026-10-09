#!/usr/bin/env bash
# C2-33 PundiX — CI custom job (read-only, public endpoints only, no secrets).
# Re-verifies governance parameters, balances, escrows and capture economics
# against the live PUNDIX chain; writes results to ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."

echo "== C2-33 PundiX verification $(date -u +%FT%TZ) =="
echo "host: $(uname -a)"
python3 --version

python3 ci/verify.py
RC=$?

echo "== ci-out contents =="
find ci-out -type f | sort
echo "== rc=$RC =="
exit $RC
