#!/usr/bin/env bash
# RPC helpers for ApeSwap Lending recon (read-only).
export BSC_RPC="${BSC_RPC:-https://bsc-rpc.publicnode.com}"
C() { cast call --rpc-url "$BSC_RPC" "$@"; }
B() { cast block-number --rpc-url "$BSC_RPC"; }
