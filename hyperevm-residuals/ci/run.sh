#!/usr/bin/env bash
# Custom CI heavy job for hyperevm-residuals (H-32 Nest + H-33 Hybra).
# Runs from the finding folder root on GitHub Actions. Read-only against public RPCs.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

echo "=== [1/2] live-state snapshot (Nest + Hybra) ==="
python3 ci/snapshot.py 2>&1 | tee ci-out/snapshot.log

echo "=== [2/2] done; artifacts in ci-out/ ==="
ls -la ci-out/
