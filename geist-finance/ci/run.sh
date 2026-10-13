#!/usr/bin/env bash
# Custom CI job for geist-finance: enumerate all current borrowers + health factors.
# Heavy RPC work; runs on the GitHub runner (FANTOM_RPC_URL secret is non-functional,
# so the script falls back to keyless public endpoints).
set -uo pipefail
cd "$(dirname "$0")/.."   # geist-finance/
mkdir -p ci-out
if [ -s ci-out/borrowers.json ] && grep -q '"borrowers"' ci-out/borrowers.json; then
  echo "[ci] borrower scan results already present, skipping rescan"
else
  echo "[ci] geist-finance borrower scan starting $(date -u +%FT%TZ)"
  python3 analysis/scan_borrowers.py > ci-out/scan-stdout.txt 2> ci-out/scan-stderr.txt
  echo "[ci] scan exit=$?"
fi
ls -la ci-out/ || true
tail -c 2000 ci-out/scan-stderr.txt 2>/dev/null || true
