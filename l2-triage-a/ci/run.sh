#!/usr/bin/env bash
# L2-Triage-A custody enumeration — heavy job (runs on GitHub Actions).
# Read-only network calls (RPC + GoldRush + public APIs). No secrets are written to files.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root

echo "[l2-triage-a] start $(date -u +%FT%TZ)"
python3 --version
python3 ci/enumerate.py
RC=$?
echo "[l2-triage-a] enumerate.py rc=$RC"
ls -la ci-out/ 2>/dev/null || true
du -sh ci-out/* 2>/dev/null || true
echo "[l2-triage-a] end $(date -u +%FT%TZ)"
exit $RC
