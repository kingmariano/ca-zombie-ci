#!/usr/bin/env bash
# C2-57 CI job — Kava Mint/Lend full census + solvency + simulate proofs (read-only).
# Uses keyless public LCD only (no secrets). Writes results to ci-out/.
set -euo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out
python3 --version
python3 analysis/scan_kava.py
echo "=== ci-out ==="
ls -la ci-out
