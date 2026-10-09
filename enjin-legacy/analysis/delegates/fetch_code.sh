#!/usr/bin/env bash
# Fetch verified source/metadata for a list of contracts via Etherscan V2. Key read from ../../../.env at runtime.
set -euo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env; set +a
mkdir -p code
for a in "$@"; do
  out="code/${a}.json"
  if [ ! -s "$out" ]; then
    curl -s --max-time 60 "https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address=${a}&apikey=${ETHERSCANV2_API_KEY}" -o "$out"
    sleep 0.3
  fi
  python3 - "$out" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
r=d.get('result',[{}])
r=r[0] if isinstance(r,list) and r else {}
print(sys.argv[1], '|', r.get('ContractName','?'), '|verified:', bool(r.get('SourceCode')), '|proxy:', r.get('Proxy'))
PY
done
