#!/usr/bin/env bash
# =============================================================================
# xrpl-evm — CI verification job (read-only)
# Verifies live on XRPL EVM mainnet that the cosmos/evm exploit preconditions
# for GHSA-7g4w-cg88-2cq2 (SubBalance underflow) and GHSA-367m-g444-9mg3
# (non-atomic StateDB commit) remain absent, and that the deployed release
# binary carries the upstream guards. No transactions, no keys, no secrets.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."   # -> xrpl-evm/

mkdir -p ci-out
echo "=== XRPL EVM live gate verification ==="
python3 analysis/verify_live.py ci-out | tee ci-out/verify_live.log
