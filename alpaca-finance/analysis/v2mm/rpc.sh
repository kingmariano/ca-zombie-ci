#!/bin/bash
# Read-only helper: cast call pinned to BLOCK via blastapi (fallback drpc)
export B=125624409
export RPC=${RPC:-https://bsc-mainnet.public.blastapi.io}
export RPC2=https://bsc.drpc.org
c() { # c <to> <sig> [args...]
  local to="$1"; shift
  local out
  out=$(cast call "$to" "$@" --block $B --rpc-url $RPC 2>&1) || out=$(cast call "$to" "$@" --block $B --rpc-url $RPC2 2>&1)
  echo "$out"
}
