#!/usr/bin/env bash
# C2-09 Archway — CWA-2026-006 wasmer-level differential campaign.
# Runs on GitHub Actions via poc.yml with finding=archway-wasmer-lab.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

bash wasmer-lab/ci_campaign.sh 2>&1 | tee ci-out/wasmer_campaign.log
