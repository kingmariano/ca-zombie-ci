#!/usr/bin/env python3
import json, os, urllib.request
from web3 import Web3
RPC="https://ethereum-rpc.publicnode.com"
COMPTROLLER=Web3.to_checksum_address("0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA")
TOPIC="0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80"
MARKETS={"caUSDT":"0x0f864A3e50D1070adDE5100fd848446C0567362B",
 "caUSDC":"0xc3aD34De18B59A24BD0877e454Fb924181F09C8f",
 "caETH":"0x37DE57183491Fa9745d8Fa5DCd950f0c3a4645c9",
 "caWBTC":"0xDa5928d59ECE82808Af2cbBE4f2872FeA8E12CD6",
 "caRPC":"0xF61159B4a0EE5b1615c9Afb3dA38111043344c32"}
KEY=os.environ.get("ETHERSCANV2_API_KEY") or [l.split("=",1)[1].strip().strip('"') for l in open("/home/heisenberg/CA/.env") if l.startswith("ETHERSCANV2_API_KEY=")][0]
w3=Web3(Web3.HTTPProvider(RPC))
ct_abi=[{"name":"getAccountLiquidity","outputs":[{"type":"uint256"},{"type":"uint256"},{"type":"uint256"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"}]
ct=w3.eth.contract(address=COMPTROLLER,abi=ct_abi)
borrowers={}
for name,addr in MARKETS.items():
    url=f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&address={addr}&topic0={TOPIC}&fromBlock=0&toBlock=latest&page=1&offset=1000&apikey={KEY}"
    d=json.load(urllib.request.urlopen(url))
    res=d.get("result")
    if not isinstance(res,list): print(name,"ERR",str(d)[:100]); continue
    for log in res:
        b=Web3.to_checksum_address("0x"+log["data"][2:][24:64])
        borrowers.setdefault(b,set()).add(name)
    print(name,"logs",len(res))
print("unique borrowers:",len(borrowers))
out=[]
for b,ms in sorted(borrowers.items()):
    try:
        err,liq,short=ct.functions.getAccountLiquidity(b).call()
        out.append({"borrower":b,"markets":sorted(ms),"liquidity_usd":liq/1e18,"shortfall_usd":short/1e18})
    except Exception as e:
        out.append({"borrower":b,"error":str(e)[:80]})
out.sort(key=lambda x: -x.get("shortfall_usd",0))
print(json.dumps(out,indent=1))
open("/home/heisenberg/CA/c-13/analysis/big_markets_borrower_health.json","w").write(json.dumps(out,indent=1))
