#!/usr/bin/env bash
# C-24 heavy enumeration job: locker records, token balances, V3 registry, valuation.
#
# The heavy enumeration/valuation outputs are committed under ci-out/ (from the first
# green run). If they are present, skip regeneration (the run then only re-runs
# post-processing + the Foundry PoC suite, which the workflow invokes afterwards).
# Delete ci-out/*.json or set FORCE_ENUM=1 to force a full regeneration.
set -uo pipefail
mkdir -p ci-out

if [ "${FORCE_ENUM:-0}" != "1" ] && [ -f ci-out/valuation.json ] && [ -f ci-out/valuation_v3.json ] \
   && [ -f ci-out/bsc_0x5b5e.json ] && [ -f ci-out/v3_bsc.json ]; then
  echo "=== [reuse] committed enumeration/valuation found; skipping heavy regeneration ==="
  ls -la ci-out/*.json | head -40
else
  echo "=== C-24 enumerate ==="
  python3 analysis/ci_enumerate.py 2>&1 | tee ci-out/00_enumerate.log
  echo "=== C-24 value ==="
  python3 analysis/ci_value.py 2>&1 | tee ci-out/01_value.log
  echo "=== C-24 variant probes ==="
  python3 analysis/ci_variant_probe.py 2>&1 | tee ci-out/02_variant_probe.log || true
fi

echo "=== C-24 post-process ==="
python3 analysis/ci_postprocess.py 2>&1 | tee ci-out/03_postprocess.log || true
echo "=== ci-out ==="
ls -la ci-out/
