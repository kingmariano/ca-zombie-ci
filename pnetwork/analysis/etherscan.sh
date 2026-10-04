#!/usr/bin/env bash
# Etherscan V2 helper (read-only). Usage: etherscan.sh <chainid> <query-string-without-apikey>
# Example: etherscan.sh 1 "module=contract&action=getcontractcreation&contractaddresses=0x..."
set -euo pipefail
source /home/heisenberg/CA/.env
CHAIN="$1"; Q="$2"
curl -s "https://api.etherscan.io/v2/api?chainid=${CHAIN}&${Q}&apikey=${ETHERSCANV2_API_KEY}"
