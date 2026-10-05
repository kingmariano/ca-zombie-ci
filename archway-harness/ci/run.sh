#!/usr/bin/env bash
# C2-09 Archway — differential harness campaign (CWA-2026-006 trigger research).
# Runs on GitHub Actions via poc.yml with finding=archway-harness.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out/harness

bash harness/ci_campaign.sh 2>&1 | tee ci-out/harness/campaign.log
