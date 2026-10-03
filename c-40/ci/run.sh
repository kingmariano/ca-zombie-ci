#!/usr/bin/env bash
# C-40 custom CI job: independent read-only re-verification of the Nostra Starknet finding.
# Light network-only work (no CPU-heavy jobs needed). Results -> c-40/ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
python3 -m pip install --quiet pycryptodome
python3 ci/verify_nostra.py 2>&1 | tee ci-out/nostra_verification.log
exit "${PIPESTATUS[0]}"
