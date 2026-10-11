#!/usr/bin/env bash
# Fetch verified sources from Etherscan V2 for Convergence Fi contracts (public data only).
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
: "${ETHERSCANV2_API_KEY:?need key}"
mkdir -p sources
addrs=(
  0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7   # tower
  0xA3A8cDA21f50b6737385E46FC9495a9998B05Ff0   # global viewer
  0x97efFB790f2fbB701D88f89DB4521348A2B77be8   # CVG token
  0x4b3Bd8906083bDE267A79E4131AF7a6f723960c8   # stkCVGETH
  0x865E59EBc3EE9EdD5656cD79b382f5153E466545   # stkCVGCVGSDT
  0x2191DF768ad71140F9F3E96c1e4407A4aA31d082   # cvgCVX
)
for a in "${addrs[@]}"; do
  out="sources/${a}.json"
  if [ ! -s "$out" ]; then
    curl -s --max-time 30 -A "Mozilla/5.0 zombie-research" \
      "https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address=${a}&apikey=${ETHERSCANV2_API_KEY}" -o "$out"
    sleep 0.4
  fi
  python3 - "$out" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
r=(d.get("result") or [{}])[0]
print(f"{r.get('ContractName','?'):40s} verified={bool(r.get('SourceCode'))} proxy={r.get('Proxy','0')} impl={r.get('Implementation','')} compiler={r.get('CompilerVersion','')}")
PY
done
