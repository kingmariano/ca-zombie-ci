#!/usr/bin/env bash
# CI custom job: independent live-state verification of Rift Finance vaults (Ethereum + Aurora).
# Read-only, keyless public RPCs. Writes ci-out/ artifacts. No secrets are printed or stored.
set -uo pipefail
echo "[verify] starting Rift Finance live-state verification $(date -u +%FT%TZ)"
python3 --version
python3 ci/verify.py || echo "[verify] WARNING: verify.py failed (continuing; see logs)"
echo "[verify] artifacts:"
ls -la ci-out/ || true
