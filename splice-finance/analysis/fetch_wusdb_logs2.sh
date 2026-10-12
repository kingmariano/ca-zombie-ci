#!/usr/bin/env bash
# Read-only: re-query StrategyDebtMigrated with correct topic0 + attacker EOA txs on Blast.
set -u
ENVF=/home/heisenberg/CA/.env
export ETHERSCANV2_API_KEY="$(grep -E '^ETHERSCANV2_API_KEY=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
OUT=/home/heisenberg/CA/splice-finance/analysis/logs
mkdir -p "$OUT"
V=0x4BeD2A922654cAcC2Be974689619768FaBF24855
curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
  --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
  --data-urlencode "fromBlock=0" --data-urlencode "toBlock=latest" --data-urlencode "address=$V" \
  --data-urlencode "topic0=0x47ff4c50c7f4d1895b7b0b281b0545eb76493a9d3a22d21b0ca4073ceef47275" \
  --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/wusdb_debt_migrated.json"
curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
  --data-urlencode "chainid=81457" --data-urlencode "module=logs" --data-urlencode "action=getLogs" \
  --data-urlencode "fromBlock=0" --data-urlencode "toBlock=latest" --data-urlencode "address=$V" \
  --data-urlencode "topic0=0xac2d5a3a47c15d35354a9e217defda494d018314f05170b7bfabb20d7807e5af" \
  --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/wusdb_strategy_withdraw.json"
# attacker EOA txs on Blast
curl -s --max-time 90 -G "https://api.etherscan.io/v2/api" \
  --data-urlencode "chainid=81457" --data-urlencode "module=account" --data-urlencode "action=txlist" \
  --data-urlencode "address=0x02228b0afcdbedf8180d96fc181da3af5dd1d1ab" \
  --data-urlencode "startblock=0" --data-urlencode "endblock=latest" --data-urlencode "sort=asc" \
  --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/attacker_txs_blast.json"
for f in wusdb_debt_migrated wusdb_strategy_withdraw attacker_txs_blast; do
python3 - "$OUT/$f.json" "$f" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); r=j.get("result")
if isinstance(r,list):
    print("==",sys.argv[2],"->",len(r),"entries")
    for lg in r[:20]:
        if "blockNumber" in lg:
            bn=int(lg["blockNumber"],16)
            extra=""
            if "topics" in lg:
                t=lg["topics"]; extra="topics1="+t[1][-40:] if len(t)>1 else ""
                d=lg["data"][2:]
                w=[d[i:i+64] for i in range(0,len(d),64)]
                if len(w)>=3: extra+=f" w0=0x{w[0][-40:]} w1=0x{w[1][-40:]} w2={int(w[2],16)/1e18:.6f}"
                extra+=f" tx={lg['transactionHash']}"
            else:
                extra=f"to={lg.get('to')} value={int(lg.get('value','0'))/1e18:.6f} input={lg.get('input','')[:20]} tx={lg['hash']}"
            print(f"   block {bn} {extra}")
else: print("==",sys.argv[2],"->",str(j.get("message"))[:100],str(r)[:200])
PY
done
