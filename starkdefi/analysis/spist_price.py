#!/usr/bin/env python3
"""Reparse SPIST pools with correct get_reserves layout (r0,r1,ts); derive SPIST price."""
import json, urllib.request, subprocess, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")
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
        time.sleep(0.4)
    raise RuntimeError(str(last)[:140])
def sel(f):
    h=subprocess.run(["cast","keccak",f],capture_output=True,text=True).stdout.strip()
    return hex(int(h,16)&((1<<250)-1))
def call(a,s,cd,block): return rpc("starknet_call",[{"contract_address":a,"entry_point_selector":s,"calldata":cd},{"block_number":block}])
def u256(r,i=0): return int(r[i],16)+(int(r[i+1],16)<<128)

def main():
    block=rpc("starknet_blockNumber",[])
    jp=json.load(open(os.path.join(OUT,"jediswap_pairs.json")))
    prices=json.load(open(os.path.join(OUT,"token_prices.json")))
    def price(t): return prices.get(f"starknet:{t}",{}).get("price")
    S_T0=sel("token0"); S_T1=sel("token1"); S_RES=sel("get_reserves"); S_DEC=sel("decimals")

    # re-probe all pairs to find SPIST pairs (token0/1) -- reuse previous list? not saved.
    # Instead: previous run printed 29 SPIST pools; re-fetch token0/1 for all pairs quickly in batches of endpoints.
    n=jp["n"]; pairs=jp["pairs"]
    def probe(p):
        try:
            t0=call(p,S_T0,[],block)[0]; t1=call(p,S_T1,[],block)[0]
            return p,t0,t1
        except Exception:
            return p,None,None
    toks={}
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs=[ex.submit(probe,p) for p in pairs]
        for i,f in enumerate(as_completed(futs)):
            p,t0,t1=f.result(); toks[p]=(t0,t1)
            if (i+1)%300==0: print("tok",i+1,"/",n,flush=True)
    spist_pairs=[p for p,(t0,t1) in toks.items() if t0==SPIST or t1==SPIST]
    print("SPIST pools:",len(spist_pairs))
    rows=[]
    for p in spist_pairs:
        t0,t1=toks[p]
        r=call(p,S_RES,[],block)
        r0=u256(r,0); r1=u256(r,2); ts=int(r[4],16)
        other = t1 if t0==SPIST else t0
        spist_res = r0 if t0==SPIST else r1
        other_res = r1 if t0==SPIST else r0
        d_other=None
        try: d_other=int(call(other,S_DEC,[],block)[0],16)
        except Exception: pass
        d_spist=18
        p_other=price(other)
        implied=None; pool_usd=None
        if p_other and d_other:
            other_whole=other_res/10**d_other
            spist_whole=spist_res/1e18
            if spist_whole>0:
                implied=p_other*other_whole/spist_whole
                pool_usd=other_whole*p_other*2
        rows.append({"pool":p,"t0":t0,"t1":t1,"r0":str(r0),"r1":str(r1),"ts":ts,
                     "other":other,"other_dec":d_other,"spist_res":str(spist_res),
                     "other_res":str(other_res),"other_price":p_other,"implied_spist_price":implied,"pool_usd_est":pool_usd})
    rows.sort(key=lambda r:-(r["pool_usd_est"] or 0))
    json.dump(rows,open(os.path.join(OUT,"spist_pools.json"),"w"),indent=1)
    for r in rows[:15]:
        print(f"  pool {r['pool'][:18]} other={r['other'][:12]} dec={r['other_dec']} spist={int(r['spist_res'])/1e18:>18.6g} other={int(r['other_res'])/10**(r['other_dec'] or 18):.6g} px={r['other_price']} implied=${r['implied_spist_price']} poolUSD={r['pool_usd_est']}")
    # summary
    valid=[r for r in rows if r["implied_spist_price"]]
    print("pools with price signal:",len(valid))
    if valid:
        import statistics
        med=statistics.median(r["implied_spist_price"] for r in valid)
        print("median implied SPIST price:",med)

if __name__=="__main__":
    main()
