#!/usr/bin/env python3
"""JediSwap V1 pair enumeration: find SPIST pools + value JEDI-P tokens held by StarkDeFi."""
import json, urllib.request, subprocess, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = ["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")
JFACTORY="0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
SPIST="0x6182278e63816ff4080ed07d668f991df6773fd13db0ea10971096033411b11"

def rpc(method, params, timeout=45, retries=5):
    last=None
    for i in range(retries):
        url=ENDPOINTS[i%len(ENDPOINTS)]
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: out=json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last=out
        except Exception as e: last=repr(e)
        time.sleep(0.3)
    raise RuntimeError(str(last)[:140])

def sel(f):
    h=subprocess.run(["cast","keccak",f],capture_output=True,text=True).stdout.strip()
    return hex(int(h,16)&((1<<250)-1))
def call(a,s,cd,block): return rpc("starknet_call",[{"contract_address":a,"entry_point_selector":s,"calldata":cd},{"block_number":block}])
def u256(r,i=0): return int(r[i],16)+(int(r[i+1],16)<<128)

def main():
    block=rpc("starknet_blockNumber",[])
    print("block",block,flush=True)
    # get_all_pairs
    res=call(JFACTORY,sel("get_all_pairs"),[],block)
    n=int(res[0],16)
    pairs=res[1:1+n]
    print("JediSwap pairs:",n,flush=True)
    json.dump({"block":block,"n":n,"pairs":pairs}, open(os.path.join(OUT,"jediswap_pairs.json"),"w"))

    S_T0=sel("token0"); S_T1=sel("token1"); S_RES=sel("get_reserves"); S_TS1=sel("total_supply"); S_TS2=sel("totalSupply")
    def probe(p):
        try:
            t0=call(p,S_T0,[],block)[0]; t1=call(p,S_T1,[],block)[0]
            return p,t0,t1
        except Exception as e:
            return p,None,None
    tok={}
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs=[ex.submit(probe,p) for p in pairs]
        for i,f in enumerate(as_completed(futs)):
            p,t0,t1=f.result()
            tok[p]=(t0,t1)
            if (i+1)%200==0: print("  tok",i+1,"/",n,flush=True)
    # find SPIST pairs
    spist_pairs=[p for p,(t0,t1) in tok.items() if t0==SPIST or t1==SPIST]
    print("SPIST pairs:",len(spist_pairs))
    out={}
    for p in spist_pairs:
        t0,t1=tok[p]
        r=call(p,S_RES,[],block)
        # Cairo-0 get_reserves returns (reserve0:Uint256, ts:felt, reserve1:Uint256) -> [r0low,r0high,ts,r1low,r1high]
        r0=u256(r,0); r1=u256(r,3)
        # total supply of LP
        ts=None
        for s in (S_TS1,S_TS2):
            try:
                v=call(p,s,[],block); ts=u256(v); break
            except Exception: pass
        out[p]={"token0":t0,"token1":t1,"res0":str(r0),"res1":str(r1),"lp_supply":str(ts) if ts else None}
        print(" SPIST pool",p[:18],"t0",t0[:12],"t1",t1[:12],"r0",r0,"r1",r1,"lp",ts)
    # JEDI-P tokens held by StarkDeFi drainable pairs: value via own reserves + lp supply
    lp=json.load(open(os.path.join(OUT,"lp_token_info.json")))
    for t in lp:
        if t in tok: 
            t0,t1=tok[t]
            r=call(t,S_RES,[],block)
            r0=u256(r,0); r1=u256(r,3)
            ts=None
            for s in (S_TS1,S_TS2):
                try:
                    v=call(t,s,[],block); ts=u256(v); break
                except Exception: pass
            lp[t].update({"t0":t0,"t1":t1,"r0":str(r0),"r1":str(r1),"lp_supply":str(ts) if ts else None})
            print(" JEDI-P",t[:18],"t0",t0[:12],"t1",t1[:12],"r0",r0,"r1",r1,"lp",ts)
    json.dump(lp,open(os.path.join(OUT,"lp_token_info.json"),"w"),indent=1)
    json.dump(out,open(os.path.join(OUT,"spist_pools.json"),"w"),indent=1)

if __name__=="__main__":
    main()
