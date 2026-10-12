#!/usr/bin/env bash
# Read-only: fetch verified source for the wUSDB implementation + probe sWETH/sUSDB bytecode.
set -u
ENVF=/home/heisenberg/CA/.env
export ETHERSCANV2_API_KEY="$(grep -E '^ETHERSCANV2_API_KEY=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
OUT=/home/heisenberg/CA/splice-finance/analysis/etherscan-vaults
mkdir -p "$OUT"
for pair in "wusdb_impl:0xa8516ff9d132ed3a3c352fe04f05fe117bae97ce" "sweth:0x8A444bF22B490fCcee46959678F070256F06729A" "susdb:0x33413CA090fD09127e0c8cA86a1b68ae00209Ae9"; do
  name="${pair%%:*}"; a="${pair##*:}"
  curl -s --max-time 60 -G "https://api.etherscan.io/v2/api" \
    --data-urlencode "chainid=81457" --data-urlencode "module=contract" \
    --data-urlencode "action=getsourcecode" --data-urlencode "address=$a" \
    --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/$name.json"
  python3 - "$OUT/$name.json" "$name" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); r=j.get("result")
if isinstance(r,list) and r:
    r=r[0]
    print(sys.argv[2],"|",r.get("ContractName"),"|",r.get("CompilerVersion"),"| Proxy:",r.get("Proxy"),"| src_len:",len(r.get("SourceCode") or ""))
else: print(sys.argv[2],"|",j.get("message"),str(r)[:100])
PY
  sleep 0.4
done
