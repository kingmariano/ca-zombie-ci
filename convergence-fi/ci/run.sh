#!/usr/bin/env bash
# Custom CI job: dump Convergence Fi live state at the CI fork block into ci-out/.
# Read-only. No secrets are printed. Runs from <folder>/ in GitHub Actions.
set -uo pipefail
mkdir -p ci-out
python3 ci/state_dump.py 2>&1 | tee ci-out/state-dump.log
