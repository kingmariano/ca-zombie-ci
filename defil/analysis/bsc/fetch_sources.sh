#!/usr/bin/env bash
# Fetch verified sources from Etherscan V2 (chainid=56). Key read from env, never persisted.
set -u
OUT=src
mkdir -p "$OUT"
ADDRS=(
  "FILST:0x899e2a220CBC6eb1Ab154211353EDED74BC1e266"
  "DFL:0x6ded0F2c886568Fb4Bb6F04f179093D3D167c9D7"
  "EFIL:0x22B475f3e93390b7E523873ad7073337f4E56C2c"
  "Staking_FILST_USDT:0xde6239b3138910c68f318e799b3d332925e9929f"
  "Staking_FILST_EFIL:0x6b9ee349810e660dda9e3557c7a7412e5424ea39"
  "Staking_FILST:0x6c753ca90bad578504314699580c8b01e067a765"
  "Staking_DFL:0x272257bb03a2b99978a1e6badeba7ccba444d285"
  "Staking_P2:0x6b6811a710f07b8ac430f6e172833e87c4bd8716"
  "SUP1:0xFA6bF5bE237570Cf326CeEeC2b467A38b4FCCAa0"
  "SUP2:0x2426da4e8FCEA0e39aDa3EA671767a236AD39e09"
  "SUP3:0xe0F23BeE9c884Bf28eBC75Ee59FD12377E59A327"
  "SUP3_superior:0x0c6D278afc34eAC4539ee33192E28275955A1BE6"
  "MiningNFT:0xB02F118013150C7F2D4F2030E15F198E1CaA60eb"
  "MiningNFTManage:0x3e3945c7e5cb7a6286b48A016d9D52B5826c3F4e"
  "PriceConverter:0xb94E91ea1cf2AB3c44f48123d9e81CA5CDF6fa82"
  "LP_FILST_USDT:0xecf6aA34b19e31311eB92768888bdDd25aa72933"
  "LP_FILST_EFIL:0x3ce2669C9aAF8E717c739B1E9100FA792AD23835"
  "LP_DFL_USDT:0x3558C47C0f2309197857689d84Cb620405E2c54D"
  "LP_FILST_WBNB:0xBEbF6B86479f9c262127a1a0b30BfD7C589B293D"
  "LP_EFIL_WBNB:0x638D513a208396EBee8B9d3cb009057aB60281bb"
  "LP_EFIL_BUSD:0x49A4DeC46A345Cc9a94Cae31d2671222CD5b95b1"
)
for entry in "${ADDRS[@]}"; do
  name="${entry%%:*}"; addr="${entry#*:}"
  out="$OUT/${name}_${addr:0:10}.json"
  if [ -f "$out" ]; then echo "skip $name"; continue; fi
  curl -s --max-time 30 "https://api.etherscan.io/v2/api?chainid=56&module=contract&action=getsourcecode&address=${addr}&apikey=${ETHERSCANV2_API_KEY}" > "$out"
  res=$(python3 -c "
import json
try:
    d=json.load(open('$out'))
    r=d.get('result')
    if isinstance(r,list) and r: print(r[0].get('ContractName'), '|', r[0].get('CompilerVersion'), '| verified' if (r[0].get('SourceCode') or '').strip() else '| UNVERIFIED')
    else: print('API:', str(r)[:80])
except Exception as e: print('ERR', e)
")
  echo "$name $addr => $res"
  sleep 0.3
done
