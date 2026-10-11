#!/usr/bin/env python3
"""Check NFT position ownership in the SdtStakingPositionManager + price remaining tokens."""
import json, os, urllib.request
RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL")
def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"python-research"})
    with urllib.request.urlopen(req, timeout=60) as r: return json.load(r)["result"]
def batch(calls):
    out=[]
    for i in range(0,len(calls),5):
        chunk=calls[i:i+5]
        body=[{"jsonrpc":"2.0","id":i+j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        for attempt in range(5):
            try:
                req=urllib.request.Request(RPC,data=json.dumps(body).encode(),
                    headers={"Content-Type":"application/json","User-Agent":"python-research"})
                with urllib.request.urlopen(req,timeout=90) as r:
                    res=json.load(r)
                break
            except Exception as e:
                if attempt==4: raise
                import time; time.sleep(2)
        if isinstance(res,dict): res=[res]
        m={x["id"]:x.get("result") for x in res}
        out += [m.get(i+j) for j in range(len(chunk))]
    return out
def u(w): return int(w,16) if w and w!="0x" else 0
def ad(w): return "0x"+w[-40:] if w and len(w)>=40 else None
def pad(n): return format(n,"064x")
def pad_a(a): return a.lower().replace("0x","").rjust(64,"0")

MGR="0x7319662aD7D7ce2d1595073EA042B723F6d0dc48"
SEL={"totalSupply":"0x18160ddd","nextId":"0x61b8ce8c","ownerOf":"0x6352211e","stakingPerTokenId":"0x83cf12ec",
     "symbol":"0x95d89b41"}
blk=int(rpc("eth_blockNumber",[]),16)
tot=u(rpc("eth_call",[{"to":MGR,"data":SEL["totalSupply"]},"latest"]))
nxt=u(rpc("eth_call",[{"to":MGR,"data":SEL["nextId"]},"latest"]))
print("manager totalSupply(NFTs):",tot,"nextId:",nxt,"block",blk)
# enumerate all tokenIds 1..nxt-1: owner + staking contract (batch)
calls=[]
for tid in range(1,nxt):
    calls.append(("eth_call",[{"to":MGR,"data":SEL["ownerOf"]+pad(tid)},"latest"]))
    calls.append(("eth_call",[{"to":MGR,"data":SEL["stakingPerTokenId"]+pad(tid)},"latest"]))
res=batch(calls)
owners={}
rows=[]
for i,tid in enumerate(range(1,nxt)):
    o=ad(res[i*2]); s=ad(res[i*2+1])
    rows.append({"tokenId":tid,"owner":o,"service":s})
    owners[o]=owners.get(o,0)+1
json.dump({"block":blk,"totalSupply":tot,"nextId":nxt,"rows":rows},open("nft_owners.json","w"),indent=1)
print("distinct owners:",len(owners))
for o,c in sorted(owners.items(),key=lambda x:-x[1])[:25]:
    print(f"  {o} : {c} NFTs")
