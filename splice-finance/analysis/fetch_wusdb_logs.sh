#!/usr/bin/env bash
# Read-only: fetch logs for wUSDB vault (Blast) from Etherscan V2.
set -u
ENVF=/home/heisenberg/CA/.env
export ETHERSCANV2_API_KEY="$(grep -E '^ETHERSCANV2_API_KEY=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
OUT=/home/heisenberg/CA/splice-finance/analysis/logs
mkdir -p "$OUT"
V=0x4BeD2A922654cAcC2Be974689619768FaBF24855
# StrategyDeposit(address,address,uint256,uint256)
curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
  --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
  --data-urlencode "fromBlock=0" --data-urlencode "toBlock=latest" \
  --data-urlencode "address=$V" \
  --data-urlencode "topic0=0x1d2b1045a76b2c3ec32fb992dd65aa3ade30353ea512435cfee8259544b06a98" \
  --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/wusdb_strategy_deposit.json"
# Upgraded(address) on the proxy
curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
  --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
  --data-urlencode "fromBlock=0" --data-urlencode "toBlock=latest" \
  --data-urlencode "address=$V" \
  --data-urlencode "topic0=0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b" \
  --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/wusdb_upgraded.json"
# StrategyDebtMigrated(address,address,uint256)
curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
  --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
  --data-urlencode "fromBlock=0" --data-urlencode "toBlock=latest" \
  --data-urlencode "address=$V" \
  --data-urlencode "topic0=0x47ff4c503e9696bc47c6d7f6e2e6a02d97d5f75a8f7c8a95c1e9e5b7bfa0a1c7" \
  --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/wusdb_debt_migrated.json"
for f in "$OUT"/wusdb_*.json; do
  python3 - "$f" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
r=j.get("result")
if isinstance(r,list):
    print(sys.argv[1].split("/")[-1], "->", len(r), "logs")
    for lg in r[:10]:
        print("   block",int(lg["blockNumber"],16),"tx",lg["transactionHash"],"topics",lg["topics"][:2])
else:
    print(sys.argv[1].split("/")[-1],"->",str(j.get("message"))[:100],str(r)[:150])
PY
done
