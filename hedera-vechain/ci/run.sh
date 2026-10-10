#!/usr/bin/env bash
# H2-06 non-EVM deep dive — main CI job (runs from folder root in GitHub Actions).
# Keyless public endpoints only; read-only; no secrets. Results -> ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

echo "===== H2-06 non-EVM: Hedera probes ====="
bash analysis/hedera/ci/probe_hedera.sh; RC_HEDERA=$?
echo "hedera probes rc=$RC_HEDERA"

echo "===== H2-06 non-EVM: cross-chain state recheck ====="
bash ci/crosschain.sh ci-out || echo "WARN: crosschain recheck exited non-zero"

echo "===== H2-06 non-EVM: child-chain scripts (if present) ====="
for s in analysis/*/ci/run.sh; do
  [ -f "$s" ] || continue
  echo "--- running $s ---"
  bash "$s" || echo "WARN: $s exited non-zero"
done

echo "===== ci-out contents ====="
ls -la ci-out/ || true
exit $RC_HEDERA
