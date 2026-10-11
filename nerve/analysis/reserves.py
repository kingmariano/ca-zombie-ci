#!/usr/bin/env python3
"""Full reserve accounting: actual vs internal vs admin for all Nerve pools."""
import json, urllib.request

RPC = "https://bsc-rpc.publicnode.com"
def pad(x): return x.lower().replace("0x","").rjust(64,"0")
def rpc_batch(calls, url=RPC):
    payload=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
    with urllib.request.urlopen(req,timeout=90) as r: out=json.load(r)
    out.sort(key=lambda x:x["id"]); return [o.get("result") for o in out]

POOLS = {
 "3pool_1b37": {"addr":"0x1b3771a66ee31180906972580ade9b81afc5fcdc",
   "tokens":{"BUSD":"0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56","USDT":"0x55d398326f99059fF775485246999027B3197955","USDC":"0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d"}},
 "btc_6C34": {"addr":"0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
   "tokens":{"BTCB":"0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c","nrvBTC":"0x54261774905f3e6e9718f2abb10ed6555cae308a"}},
 "eth_146C": {"addr":"0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0",
   "tokens":{"ETH":"0x2170Ed0880ac9A755fd29B2688956BD959F933F8","nrvETH":"0x6f817a0ce8f7640add3bc0c1c2298635043c2423"}},
 "meta_2dcC": {"addr":"0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
   "tokens":{"UST":"0x23396cF899Ca06c4472205fC903bDB4de249D6fC","3poolLP":"0xf2511b5e4fb0e5e2d123004b672ba14850478c14"}},
}

def main():
    bh = rpc_batch([("eth_blockNumber",[])])[0]; block=int(bh,16)
    calls, meta = [], []
    for pn,p in POOLS.items():
        for tn,t in p["tokens"].items():
            calls.append(("eth_call",[{"to":t,"data":"0x313ce567"},bh])); meta.append((pn,tn,"decimals"))
            calls.append(("eth_call",[{"to":t,"data":"0x70a08231"+pad(p["addr"])},bh])); meta.append((pn,tn,"actual"))
    for pn,p in POOLS.items():
        for i,(tn,t) in enumerate(p["tokens"].items()):
            calls.append(("eth_call",[{"to":p["addr"],"data":"0x91ceb3eb"+pad(hex(i))},bh])); meta.append((pn,tn,"internal"))
            calls.append(("eth_call",[{"to":p["addr"],"data":"0xef0a712f"+pad(hex(i))},bh])); meta.append((pn,tn,"admin"))
    res = rpc_batch(calls)
    out={}
    for (pn,tn,k),v in zip(meta,res):
        out.setdefault(pn,{}).setdefault(tn,{})[k]=v
    # compute
    for pn,toks in out.items():
        print("==",pn)
        for tn,d in toks.items():
            dec=int(d["decimals"],16) if d.get("decimals") else None
            act=int(d["actual"],16) if d.get("actual") else 0
            inte=int(d["internal"],16) if d.get("internal") else 0
            adm=int(d["admin"],16) if d.get("admin") else 0
            denom=10**dec if dec else 1
            print(f"  {tn}: dec={dec} actual={act/denom:.6f} internal={inte/denom:.6f} admin={adm/denom:.6f} | internal+admin-actual={(inte+adm-act)/denom:+.6f}")
    with open("/home/heisenberg/CA/nerve/analysis/reserves.json","w") as f:
        json.dump({"block":block,"data":out},f,indent=2)

if __name__=="__main__": main()
