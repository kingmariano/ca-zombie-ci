#!/usr/bin/env bash
# QC-2 custom CI job: fresh live-state dump for the adversarial re-audit.
# Read-only. No secrets printed. Runs from <folder>/ in GitHub Actions.
set -uo pipefail
mkdir -p ci-out
python3 ci/state_dump.py 2>&1 | tee ci-out/state-dump.log
