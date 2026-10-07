#!/usr/bin/env bash
# C2-09 Archway — E8 mint-path analysis (static, read-only).
# Runs on GitHub Actions via poc.yml with finding=archway-mint.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

bash e8/run_campaign.sh 2>&1 | tee ci-out/e8_campaign.log
