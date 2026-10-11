#!/usr/bin/env python3
"""LP tokens, admin balances, nrv tokens, recent activity for Nerve pools (BSC)."""
import json, urllib.request, sys

RPC = "https://bsc-rpc.publicnode.com"
def pad(x): return x.lower().replace("0x","").rjust(64,"0")
def rpc_batch(calls, url=RPC):
    payload=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
    with urllib.request.urlopen(req,timeout=90) as r: out=json.load(r)
    out.sort(key=lambda x:x["id"]); return [o.get("result") for o in out]

LP = {
 "3pool_LP": "0xf2511b5e4fb0e5e2d123004b672ba14850478c14",
 "btc_LP":   "0xd1d5af92c606c6f2ec59d453f57a6fcc188d7db5",
 "eth_LP":   "0x0d283bf16a9bde49cfc48d8dc050af28b71bdd90",
 "meta_LP":  "0x35ce243e0dc9ed77e3c348bb2742095f78e1cb70",
}
POOLS = ["0x1b3771a66ee31180906972580ade9b81afc5fcdc","0x6C341938bB75dDe823FAAfe7f446925c66E6270c","0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0","0x2dcCe1586b1664f41C72206900e404Ec3cA130e0"]
NRV = ["0x54261774905f3e6e9718f2abb10ed6555cae308a","0x6f817a0ce8f7640add3bc0c1c2298635043c2423"]
SAFE = "0xd94ac9fb78dd9b3feb0ec39f38d86d2ee5ba6b06"
DEAD = "0x0000000000000000000000000000000000000000"

def main():
    bh = rpc_batch([("eth_blockNumber",[])])[0]; block=int(bh,16)
    calls, meta = [], []
    for n,a in LP.items():
        calls.append(("eth_call",[{"to":a,"data":"0x18160ddd"},bh])); meta.append((n,"totalSupply"))
        calls.append(("eth_call",[{"to":a,"data":"0x8da5cb5b"},bh])); meta.append((n,"owner"))
        for who,wn in [(SAFE,"safe"),(DEAD,"dead"),("0x2dcCe1586b1664f41C72206900e404Ec3cA130e0","metapool"),("0x1b3771a66ee31180906972580ade9b81afc5fcdc","3pool")]:
            calls.append(("eth_call",[{"to":a,"data":"0x70a08231"+pad(who)},bh])); meta.append((n,"bal:"+wn))
    for i in range(3):
        calls.append(("eth_call",[{"to":POOLS[0],"data":"0xef0a712f"+pad(hex(i))},bh])); meta.append(("3pool",f"adminBal({i})"))
    for n,a in zip(["nrvBTC","nrvETH"],NRV):
        calls.append(("eth_call",[{"to":a,"data":"0x18160ddd"},bh])); meta.append((n,"totalSupply"))
        calls.append(("eth_call",[{"to":a,"data":"0x8da5cb5b"},bh])); meta.append((n,"owner"))
        calls.append(("eth_call",[{"to":a,"data":"0x95d89b41"},bh])); meta.append((n,"symbol"))
        for who,wn in [("0x6C341938bB75dDe823FAAfe7f446925c66E6270c","btcpool"),("0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0","ethpool")]:
            calls.append(("eth_call",[{"to":a,"data":"0x70a08231"+pad(who)},bh])); meta.append((n,"bal:"+wn))
    # actual balances of pool token1 (nrv)
    res = rpc_batch(calls)
    out={}
    for (n,k),v in zip(meta,res): out.setdefault(n,{})[k]=v
    print(json.dumps({"block":block,"data":out},indent=2))
    with open("/home/heisenberg/CA/nerve/analysis/lp_state.json","w") as f:
        json.dump({"block":block,"data":out},f,indent=2)

if __name__=="__main__": main()
