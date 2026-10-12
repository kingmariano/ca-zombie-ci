#!/usr/bin/env bash
# Read-only: fetch SY sources for the Splice native vault SYs.
set -u
ENVF=/home/heisenberg/CA/.env
export ETHERSCANV2_API_KEY="$(grep -E '^ETHERSCANV2_API_KEY=' "$ENVF" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
OUT=/home/heisenberg/CA/splice-finance/analysis/etherscan
mkdir -p "$OUT"
for pair in "0xc28fb4cc69081f9f72c643c47e8fef7b4ab2e7aa:swethsy" "0x0e999eb7f4e553348703d4ed804079c89e8c92f5:susdbsy"; do
  a="${pair%%:*}"; name="${pair##*:}"
  curl -s --max-time 60 -G "https://api.etherscan.io/v2/api" \
    --data-urlencode "chainid=81457" --data-urlencode "module=contract" \
    --data-urlencode "action=getsourcecode" --data-urlencode "address=$a" \
    --data-urlencode "apikey=$ETHERSCANV2_API_KEY" -o "$OUT/$a.json"
  python3 - "$OUT/$a.json" "$name" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); r=j.get("result")
if isinstance(r,list) and r:
    r=r[0]
    print(sys.argv[2],"|",r.get("ContractName"),"|",r.get("CompilerVersion"),"| Proxy:",r.get("Proxy"),"| len:",len(r.get("SourceCode") or ""))
else: print(sys.argv[2],"|",j.get("message"),str(r)[:100])
PY
  sleep 0.4
done
