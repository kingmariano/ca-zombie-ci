#!/usr/bin/env bash
# C2-04 LuaSwap (Viction) — local fork test runner (read-only; no mainnet transactions).
# Usage: ./run.sh [extra forge args]
set -euo pipefail
cd "$(dirname "$0")"
export VICTION_RPC_URL="${VICTION_RPC_URL:-https://viction.drpc.org}"
forge test -vv "$@"
