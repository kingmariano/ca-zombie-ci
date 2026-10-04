#!/usr/bin/env bash
# H-27 MilkyWay: custom CI job (read-only endpoint verification).
# Writes results to ci-out/ (uploaded as workflow artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[h27] cwd=$(pwd)"
echo "[h27] python: $(python3 --version 2>&1)"
python3 ci/verify.py 2>&1 | tee ci-out/verify.log
echo "[h27] done; evidence files:"
ls -la ci-out/ || true
