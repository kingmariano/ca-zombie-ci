#!/usr/bin/env bash
# CI job: C2-56 Huckleberry / Moonriver cohort — independent frozen-chain verification.
# Read-only. Uses MOONRIVER_RPC_URL (keyed, env) + public fallbacks. Never prints keyed URLs.
set -euo pipefail
cd "$(dirname "$0")/.."      # folder root
mkdir -p ci-out
echo "[ci] python: $(python3 --version)"
echo "[ci] keyed MOONRIVER_RPC_URL present: $([ -n "${MOONRIVER_RPC_URL:-}" ] && echo yes || echo no)"
python3 ci/verify.py 2>&1 | tee ci-out/verify.log
echo "[ci] done; artifacts:"
ls -la ci-out/
