#!/usr/bin/env bash
# Omm (ICON) heavy scan — read-only, public endpoints only. Writes to ci-out/.
set -euo pipefail
cd "$(dirname "$0")"
python3 --version
python3 omm_scan.py
echo "[ci] done; files:"
ls -la ../ci-out/ || true
