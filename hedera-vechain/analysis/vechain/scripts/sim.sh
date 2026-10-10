#!/usr/bin/env bash
# Read-only clause simulation against VeChain mainnet (keyless public endpoint).
# Usage: ./sim.sh <to> <data> [caller]
TO="$1"; DATA="$2"; CALLER="${3:-0x0000000000000000000000000000000000000001}"
curl -s --max-time 25 -X POST "https://mainnet.vechain.org/accounts/*" \
  -H "Content-Type: application/json" \
  -d "{\"clauses\":[{\"to\":\"$TO\",\"data\":\"$DATA\",\"value\":\"0x0\"}],\"caller\":\"$CALLER\",\"gas\":30000000,\"gasPrice\":\"0x0\"}"
