#!/usr/bin/env python3
"""Check fixed major-token balances for all pNetwork vault candidates on Ethereum."""
import json, sys, urllib.request, subprocess

RPC = "https://ethereum-rpc.publicnode.com"
MAJOR = {
 "USDT":"0xdAC17F958D2ee523a2206206994597C13D831ec7",
 "USDC":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
 "GALA":"0x15D4c048F83bd7e37d49eA4C83a07267Ec4203Da",
 "PNT":"0x89Ab32156e46F46D02ade3FEcbe5Fc4243B9AAeD",
 "ethPNT":"0xf4eA6B892853413bD9d9f1a5D3a620A0ba39c5b2",
 "UOS":"0xd13c7342e1ef687c5ad21b27c2b65d772cab5c8c",
 "WETH":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
 "DAI":"0x6B175474E89094C44Da98b954EedeAC495271d0F",
 "WBTC":"0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
 "LINK":"0x514910771AF9Ca656af840dff83E8264EcF986CA",
 "TLOS":"0x7825e833D495F3d1c28872415a4aee339D26AC88",
}
def sel(sig): return subprocess.check_output(["cast","sig",sig]).decode().strip()
BAL = sel("balanceOf(address)")

def batch(calls):
    payload=[{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":a,"data":d},"latest"]} for i,(a,d) in enumerate(calls)]
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    out=json.load(urllib.request.urlopen(req,timeout=120))
    res={}
    for it in out: res[it["id"]]=it.get("result",it.get("error"))
    return [res.get(i) for i in range(len(calls))]

vaults=json.load(open(sys.argv[1]))
calls=[]; meta=[]
for v in vaults:
    for sym,tk in MAJOR.items():
        calls.append((tk, BAL + v[2:].lower().rjust(64,'0')))
        meta.append((v,sym))
bals=batch(calls)
out={}
for (v,sym),b in zip(meta,bals):
    try: val=int(b,16) if isinstance(b,str) and b.startswith("0x") and len(b)>2 else 0
    except Exception: val=0
    if val: out.setdefault(v,{})[sym]=val
for v,d in out.items():
    print(v, json.dumps(d))
print("TOTAL vaults with nonzero:", len(out))
json.dump(out, open(sys.argv[2],"w"), indent=1)
