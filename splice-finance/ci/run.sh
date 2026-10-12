#!/usr/bin/env bash
# Heavy CI job for splice-finance: full live-state dump (Blast + Mode) + summary.
# Writes results into ci-out/ (uploaded as artifact). Read-only, public RPCs, no secrets printed.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> splice-finance/
mkdir -p ci-out
# Note: mode-rpc.publicnode.com is broken/limited (cloudflare 403) — use the chain RPC.
# state_dump.py already falls back across RPCs; these envs just set the preferred one.
export BLAST_RPC_URL="${BLAST_RPC_URL:-https://rpc.blast.io}"
export MODE_RPC_URL="${MODE_RPC_URL:-https://mainnet.mode.network}"
echo "[ci] state dump starting at $(date -u +%FT%TZ)"
python3 analysis/state_dump.py ci-out/state_dump.json 2>&1 | tail -5
echo "[ci] summarize"
python3 analysis/summarize.py ci-out/state_dump.json ci-out/splice_summary.json 2>&1 | tail -40
ls -la ci-out/
