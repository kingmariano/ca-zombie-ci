#!/usr/bin/env python3
"""
Enumerate Ra Exchange staking-layer state: voter pools/gauges/feeDistributors,
their token balances, gauge stakes, voting escrow, minter, base/xToken supply.
Read-only, public RPC.
"""
import json, urllib.request, time

RPC = "https://rpc.frax.com"
OUT = "/home/heisenberg/CA/ra-exchange/analysis/staking_state.json"
VOTER = "0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869"
NFP   = "0xAAA78E8C4241990B4ce159E105dA08129345946A"
VE    = "0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F"
MINTER= "0xAAA823aa799BDa3193D46476539bcb1da5B71330"
BASE  = "0xAAA9FB3a08C13BA97Ae0F518B3AfA5C4a81498Fc"
XTOKEN= "0xAAAE58986b24e422740C8F22B3efB80BCbD68159"

class Rpc:
    def __init__(self, url): self.url=url; self.id=0
    def batch(self, calls):
        payload=[]
        for (to,data) in calls:
            self.id+=1
            payload.append({"jsonrpc":"2.0","id":self.id,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
        req=urllib.request.Request(self.url,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
        for _ in range(4):
            try:
                with urllib.request.urlopen(req,timeout=60) as r: resp=json.loads(r.read())
                byid={x["id"]:x.get("result") for x in resp if isinstance(x,dict)}
                return [byid.get(i) for i in range(self.id-len(calls)+1,self.id+1)]
            except Exception: time.sleep(1.5)
        raise RuntimeError("batch failed")

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_u(n): return hex(n)[2:].rjust(64,"0")
def du(h): return None if h is None else (0 if h=="0x" else int(h,16))
def addr(h): return "0x"+h[-40:] if h and len(h)>=42 else None

def main():
    rpc=Rpc(RPC)
    with urllib.request.urlopen(urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"}),timeout=30) as r:
        block=int(json.loads(r.read())["result"],16)
    out={"block":block}
    print("block",block)

    # 1) pools list
    n = du(rpc.batch([(VOTER,"0x1f7b6d32")])[0])  # length()
    print("voter pools:",n)
    calls=[]
    for i in range(n):
        calls.append((VOTER,"0xac4afa38"+enc_u(i)))  # pools(uint256)
    pools=[addr(x) for x in rpc.batch(calls)]
    out["pools"]=pools

    # 2) gauges + fee distributors + isAlive
    calls=[]
    for p in pools:
        calls.append((VOTER,"0xb9a09fd5"+enc_addr(p)))  # gauges(pool)
    gauges=[addr(x) for x in rpc.batch(calls)]
    out["gauges"]=gauges
    calls=[]
    for g in gauges:
        calls.append((VOTER,"0x49e4974a"+enc_addr(g)))  # feeDistributors(gauge)
    fds=[addr(x) for x in rpc.batch(calls)]
    out["feeDistributors"]=fds
    calls=[]
    for g in gauges:
        calls.append((VOTER,"0x1703e5f9"+enc_addr(g)))  # isAlive(gauge)
    out["isAlive"]=[bool(du(x) or 0) for x in rpc.batch(calls)]

    # 3) balances: base, xToken on gauges and fds
    tok_bal_calls=[]
    for tgt in gauges+fds:
        tok_bal_calls.append((BASE,"0x70a08231"+enc_addr(tgt)))
        tok_bal_calls.append((XTOKEN,"0x70a08231"+enc_addr(tgt)))
    res=rpc.batch(tok_bal_calls)
    gbal={}
    for i,g in enumerate(gauges):
        gbal[g]={"base":du(res[2*i]),"xToken":du(res[2*i+1])}
    fbal={}
    for i,f in enumerate(fds):
        fbal[f]={"base":du(res[2*len(gauges)+2*i]),"xToken":du(res[2*len(gauges)+2*i+1])}
    out["gauge_bal"]=gbal
    out["fd_bal"]=fbal

    # 4) gauge token balances: token0/token1 of the pool + nfp count of staked nfts
    calls=[]
    for g in gauges:
        calls.append((g,"0x18160ddd"))  # totalSupply (staked count for ClGauge?)
    out["gauge_totalSupply"]=[du(x) for x in rpc.batch(calls)]

    # 5) voting escrow: totalSupply, supply, epoch
    ve_calls=[(VE,"0x18160ddd"),(VE,"0x047fc9aa"),(VE,"0x900cf0cf")]
    ve_res=rpc.batch(ve_calls)
    out["ve_totalSupply"]=du(ve_res[0]); out["ve_supply"]=du(ve_res[1]); out["ve_epoch"]=du(ve_res[2])

    # 6) minter state
    m_calls=[(MINTER,"0x0a441f7b"),(MINTER,"0xd33219b4"),(MINTER,"0x210ca05d"),(MINTER,"0x4995b458")]
    m_res=rpc.batch(m_calls)
    out["minter_probe"]=m_res

    # 7) base token info
    b_calls=[(BASE,"0x18160ddd"),(BASE,"0x06fdde03")]
    b_res=rpc.batch(b_calls)
    out["base_totalSupply"]=du(b_res[0])
    out["base_name_raw"]=b_res[1]

    json.dump(out,open(OUT,"w"),indent=1)
    print("wrote",OUT)

if __name__=="__main__":
    main()
