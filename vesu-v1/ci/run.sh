#!/usr/bin/env bash
# C2-50 Vesu V1.1 — CI heavy job.
# Full event enumeration + position collateralization scan + liquidation economics + gate proofs.
# Read-only; public RPC only (no secrets). Results -> ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
export CI_OUT="$PWD/ci-out"
mkdir -p "$CI_OUT"
echo "[ci] start $(date -u +%FT%TZ)"
python3 --version
echo "--- state ---"
python3 analysis/fetch_state.py 2>&1 | tail -30 || echo "[ci] state phase failed"
echo "--- events (full range) ---"
python3 analysis/enumerate.py events 2>&1 | tail -40 || echo "[ci] events phase failed"
echo "--- events V1.0 (deprecated singleton) ---"
python3 analysis/enumerate.py events-v10 2>&1 | tail -20 || echo "[ci] events-v10 phase failed"
echo "--- decode ---"
python3 analysis/enumerate.py decode 2>&1 | tail -10 || echo "[ci] decode failed"
echo "--- positions ---"
python3 analysis/enumerate.py positions 2>&1 | tail -20 || echo "[ci] positions failed"
echo "--- liquidation economics ---"
python3 analysis/enumerate.py liquidations 2>&1 | tail -30 || echo "[ci] liquidations failed"
echo "--- pools snapshot ---"
python3 analysis/enumerate.py pools 2>&1 | tail -10 || echo "[ci] pools failed"
echo "--- gate proofs ---"
python3 analysis/enumerate.py gates --config analysis/gates_config.json 2>&1 | tail -30 || echo "[ci] gates failed"
echo "--- summary ---"
python3 analysis/summary.py 2>&1 | tail -50 || echo "[ci] summary failed"
echo "[ci] outputs:"
ls -la "$CI_OUT"
echo "[ci] done $(date -u +%FT%TZ)"
