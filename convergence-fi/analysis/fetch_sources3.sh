#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
set -a; source /home/heisenberg/CA/.env 2>/dev/null; set +a
mkdir -p sources
addrs=(
  0x21777106355Ba506A31FF7984c0aE5C924deB77f   # SdtBlackHole
  0x7319662aD7D7ce2d1595073EA042B723F6d0dc48   # SdtStakingPositionManager
  0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5   # CloneFactory
  0x6B65525a40704a4c48d07c25b8D05654854DFEcD   # SdtRewardDistributor
  0x8405FF734C157f51011FC7d7dfa22f4a32505B43   # buffer of sdCRV service
  0x0af815364BD9e9E60f3d2D3bAc1320B77d3E35F7   # owner (treasury dao?)
  0xe5d6D047DF95c6627326465cB27B64A8b77A8b91   # gauge admin
)
for a in "${addrs[@]}"; do
  out="sources/${a}.json"
  if [ ! -s "$out" ]; then
    curl -s --max-time 60 -A "python-research" \
      "https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address=${a}&apikey=${ETHERSCANV2_API_KEY}" -o "$out"
    sleep 1
  fi
  python3 -c "
import json
d=json.load(open('sources/${a}.json'))
r=(d.get('result') or [{}])[0]
print(f\"${a} {r.get('ContractName','?'):35s} verified={bool(r.get('SourceCode'))} proxy={r.get('Proxy','0')} impl={r.get('Implementation','')}\")
" 2>/dev/null || echo "${a} FETCH-FAIL"
done