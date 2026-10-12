#!/usr/bin/env bash
# Read-only: fetch verified source for Blast vaults from Etherscan V2.
# The API key is read from /home/heisenberg/CA/.env at runtime and NEVER written to disk.
set -u
ENVF=/home/heisenberg/CA/.env
if [ -f "$ENVF" ]; then
  export ETHERSCANV2_API_KEY="$(grep -E '^ETHERSCANV2_API_KEY=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
fi
if [ -z "${ETHERSCANV2_API_KEY:-}" ]; then echo "NO KEY"; exit 1; fi
OUT=/home/heisenberg/CA/splice-finance/analysis/etherscan-vaults
mkdir -p "$OUT"
declare -A ADDRS=(
  [husdb]="0x390b781BAf1e6Db546cF4e3354b81446947838d2"
  [hweth]="0x1856C7e0B559E9d7287473CB4b4786398Db4032A"
  [wusdb]="0x4BeD2A922654cAcC2Be974689619768FaBF24855"
  [sweth]="0x8A444bF22B490fCcee46959678F070256F06729A"
  [susdb]="0x33413CA090fD09127e0c8cA86a1b68ae00209Ae9"
)
for name in "${!ADDRS[@]}"; do
  a="${ADDRS[$name]}"
  curl -s --max-time 60 -G "https://api.etherscan.io/v2/api" \
    --data-urlencode "chainid=81457" \
    --data-urlencode "module=contract" \
    --data-urlencode "action=getsourcecode" \
    --data-urlencode "address=$a" \
    --data-urlencode "apikey=$ETHERSCANV2_API_KEY" \
    -o "$OUT/$name.json"
  # print only status fields, no secrets
  python3 - "$OUT/$name.json" "$name" <<'PY'
import json,sys
try:
    j=json.load(open(sys.argv[1]))
    r=j.get("result")
    if isinstance(r,list) and r:
        r=r[0]
        print(sys.argv[2], "| status", j.get("status"), "| ContractName:", r.get("ContractName"),
              "| Compiler:", r.get("CompilerVersion"), "| Proxy:", r.get("Proxy"),
              "| Impl:", r.get("Implementation"), "| src_len:", len(r.get("SourceCode") or ""))
    else:
        print(sys.argv[2], "| status", j.get("status"), "| msg", str(j.get("message"))[:80], str(j.get("result"))[:120])
except Exception as e:
    print(sys.argv[2], "ERR", e)
PY
  sleep 0.5
done
