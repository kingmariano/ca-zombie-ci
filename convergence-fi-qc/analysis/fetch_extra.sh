#!/usr/bin/env bash
# Fetch verified sources for remaining Convergence contracts (Etherscan V2).
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
mkdir -p extra_sources
for a in 0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04 0x15cbdf343fA37cD555D8F8CdeaA3948c1f0C42aE 0xa044fd2E8254eC5DE93B15b8B27d005899579109 0x63312010fdc7dcacd33b6bd9d9cf0c54b0e6e6f0 0x8678186f5863a3013a180ba2b387de8e54573e06 0x31ab49528b37af1ee3ef9665cdc22e494a44ddcb; do
  curl -s "https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address=$a&apikey=$ETHERSCANV2_API_KEY" -o "extra_sources/$a.json"
  python3 - "$a" <<'EOF'
import json,sys
a=sys.argv[1]
d=json.load(open(f"extra_sources/{a}.json"))
r=d.get('result')
if isinstance(r,list) and r: r=r[0]
print(a, '=>', (r or {}).get('ContractName'), '| compiler', (r or {}).get('CompilerVersion'), '| proxy', (r or {}).get('Proxy'))
EOF
done
