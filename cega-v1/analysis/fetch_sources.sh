#!/usr/bin/env bash
# Fetch verified source + ABI from Etherscan V2 for key Cega V1 addresses.
set -uo pipefail
cd "$(dirname "$0")"
set -a && source /home/heisenberg/CA/.env && set +a
mkdir -p sources
fetch() { # chainid address label
  local cid=$1 addr=$2 label=$3
  curl -s "https://api.etherscan.io/v2/api?chainid=$cid&module=contract&action=getsourcecode&address=$addr&apikey=$ETHERSCANV2_API_KEY" > "sources/${label}_${cid}.json"
  python3 - "$cid" "$addr" "$label" <<'PY'
import json,sys
cid,addr,label=sys.argv[1:4]
d=json.load(open(f"sources/{label}_{cid}.json"))
r=d.get("result")
if isinstance(r,list) and r:
    x=r[0]
    src=x.get("SourceCode","")
    abi=x.get("ABI","")
    open(f"sources/{label}_{cid}.sol","w").write(src)
    open(f"sources/{label}_{cid}.abi","w").write(abi)
    print(f"{label} {cid} {addr}: name={x.get('ContractName')} verified={len(src)>0} abi={len(abi)}")
else:
    print(f"{label} {cid} {addr}: ERROR {str(d)[:150]}")
PY
}
# Ethereum
fetch 1 0x0730AA138062D8Cc54510aa939b533ba7c30f26B cegaState
fetch 1 0x31C73c07Dbd8d026684950b17dD6131eA9BAf2C4 productViewer
fetch 1 0x042021d59731d3fFA908c7c4211177137Ba362Ea supercharger
fetch 1 0x56F00A399151EC74cf7bE8DC38225363E84975E6 goFast
fetch 1 0x784e3C592A6231D92046bd73508B3aAe3A7cc815 insanic
fetch 1 0x2aAE28E495626F587677ca779838266DB9bD6Cd1 puppy
fetch 1 0x98b872604F36807169c096241ECD4646021de133 l2
fetch 1 0xAB8631417271Dbb928169F060880e289877Ff158 starboard
fetch 1 0xcf81b51AecF6d88dF12Ed492b7b7f95bBc24B8Af autopilot
fetch 1 0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8 cruiseControl
fetch 1 0x94C5D3C2fE4EF2477E562EEE7CCCF07Ee273B108 genesisBasket
# Arbitrum
fetch 42161 0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed cegaState
fetch 42161 0x8c32a5d9f29da36ed68a9d454eda1b374795b6ca productViewer
fetch 42161 0x6A9201Db9222cFb5164cfb8F192903270f8a6e93 puppyLov
