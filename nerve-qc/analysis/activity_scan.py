#!/usr/bin/env python3
"""Bot net-flow analysis + recent activity scan across ALL known pools."""
import json, urllib.request, os, time, subprocess

KEY=os.environ["GOLD_RUSH_API_KEY"]
def get(url,tries=4):
    for i in range(tries):
        try:
            req=urllib.request.Request(url,headers={"User-Agent":"research/1.0"})
            return json.load(urllib.request.urlopen(req,timeout=60))
        except Exception:
            if i==tries-1: raise
            time.sleep(2+2*i)

ANKR=os.environ["ANKR_API_KEY"]
RPCA=f"https://rpc.ankr.com/bsc/{ANKR}"
def rpc(m,p):
    req=urllib.request.Request(RPCA,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=60))
    if "error" in r: raise RuntimeError(str(r["error"])[:120])
    return r.get("result")

POOLS={
 "3pool":"0x1b3771a66ee31180906972580ade9b81afc5fcdc",
 "btc":"0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
 "eth":"0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0",
 "USTMETA":"0x2dcce1586b1664f41c72206900e404ec3ca130e0",
 "FUSDTMETA":"0xd0fbf0a224563d5ffc8a57e4fda6ae080ebcf3d3",
 "NRVMETA":"0x96b849a73db2cc769b4abe770aab141aac9014d6",
 "E0":"0x97b9054122ef8888590934f0ec8e10580232e85d",
 "E1":"0xc80cc653392f4734201331e39a66aa8a483d29bd",
 "E2":"0xca9d9c7800b7d1d3a1988a7d93927424a1bbea7f",
 "E3":"0xb1669a60a7db67aa84e5faf2ae3123aa99237459",
 "E4":"0xf100326c19996eaf2d8e93a503725f643e36099c",
 "E5":"0x0144e7d25644c7ca6038f4afbfcd3b1a119ab3ce",
 "E6":"0xbc7477e46a95758de5012744f7a350a4e0d03484",
 "E7":"0x0eafaa7ed9866c1f08ac21dd0ef3395e910f7114",
 "NEW1":"0x877a8437e76443cfcacd05d21c3793070637d82f",
 "NEW2":"0xcb922e4a5370020acf2d0e29754e0a995dec5b27",
 "NEW3":"0xf873ec132f38efb86bd071234b4316878b48fa97",
}
BOT="0xd42fce65b9ce5ded9d3a4ecaa20955bab52daa19"

def txlist(addr,page_size=100,maxpages=4):
    out=[]
    for pg in range(1,maxpages+1):
        d=get(f"https://api.covalenthq.com/v1/56/address/{addr}/transactions_v3/?key={KEY}&page-size={page_size}&page-number={pg}")
        items=(d.get("data") or {}).get("items") or []
        out.extend(items)
        if len(items)<page_size: break
    return out

def main():
    print("== recent activity per pool (latest tx touching it) ==")
    for name,a in POOLS.items():
        try:
            items=txlist(a,page_size=5,maxpages=1)
            if not items: print(f"{name}: no txs"); continue
            latest=items[0]
            print(f"{name}: {len(items) if len(items)<5 else '5+'} recent | latest blk {latest.get('block_height')} from {latest.get('from_address')} to {str(latest.get('to_address'))[:14]} success={latest.get('successful')}")
        except Exception as e:
            print(f"{name}: ERR {str(e)[:60]}")
    print("\n== bot full history ==")
    items=txlist(BOT,page_size=100,maxpages=5)
    print("bot txs:",len(items))
    if items:
        print("first:",items[-1].get("block_height"),"last:",items[0].get("block_height"))
        # count direct-to-pool txs
        direct=sum(1 for it in items if str(it.get("to_address","")).lower() in {v.lower() for v in POOLS.values()})
        print("direct-to-nerve-pool txs:",direct)
        from collections import Counter
        c=Counter(str(it.get("to_address","")).lower() for it in items)
        print("top targets:",c.most_common(6))
    with open("/home/heisenberg/CA/nerve-qc/analysis/bot_activity.json","w") as f:
        json.dump(items,f,indent=2)

if __name__=="__main__": main()
