#!/usr/bin/env bash
# loads RPC helpers without printing secrets
export DRPC_API_KEY="$(grep -m1 '^DRPC_API_KEY=' /home/heisenberg/CA/.env | cut -d= -f2-)"
export INFURA_API_KEY="$(grep -m1 '^INFURA_API_KEY=' /home/heisenberg/CA/.env | cut -d= -f2-)"
export BASE_RPC_URL="https://base.drpc.org"
