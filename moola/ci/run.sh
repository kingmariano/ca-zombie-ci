#!/usr/bin/env bash
# C2-17 (Moola, Celo) — custom CI job.
# Recomputes the live liquidatable dust on a public Celo RPC at the CI block.
# Read-only: eth_call / eth_blockNumber only. Results land in ci-out/ (artifact).
# The census is non-fatal: forge tests must still run if the public RPC misbehaves.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
if ! python3 ci/census.py | tee ci-out/census_stdout.txt; then
  echo "WARNING: census failed (RPC issue) — continuing so forge tests run" | tee -a ci-out/census_stdout.txt
fi
exit 0
