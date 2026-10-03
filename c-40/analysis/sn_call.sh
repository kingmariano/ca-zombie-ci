#!/usr/bin/env bash
# Starknet RPC helper (read-only). usage: sn_call.sh <method> <params-json>
RPC="${SN_RPC:-https://starknet-rpc.publicnode.com}"
curl -s -m 40 -X POST -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}" "$RPC"
