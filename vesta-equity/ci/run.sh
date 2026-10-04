#!/usr/bin/env bash
# Vesta Equity (Algorand) heavy/verification job — read-only, no transactions.
# Runs on the GitHub Actions runner (network enabled). Writes ci-out/vesta_ci_verify.json.
set -euo pipefail
python3 -m pip install --quiet --disable-pip-version-check requests py-algorand-sdk
python3 analysis/ci_verify.py
