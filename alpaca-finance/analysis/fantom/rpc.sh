#!/usr/bin/env bash
# read-only helper for Alpaca Fantom audit. No transactions, eth_call/eth_getStorageAt only.
FTM=${FTM:-https://rpcapi.fantom.network}
BSC=${BSC:-https://bsc-rpc.publicnode.com}
c(){ cast call "$@" --rpc-url ${FTM}; }
b(){ cast call "$@" --rpc-url ${BSC}; }
