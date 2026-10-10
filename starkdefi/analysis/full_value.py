#!/usr/bin/env python3
"""Full vault balance fetch + JEDI-P valuation + drainable value table (robust)."""
import json, urllib.request, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = ["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, "..", "analysis")

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
    raise RuntimeError(str(last)[:150])

import subprocess
def sel(f):
    h=subprocess.run(["cast","keccak",f],capture_output=True,text=True).stdout.strip()
    return hex(int(h,16)&((1<<250)-1))
def call(addr,s,cd,block):
    return rpc("starknet_call",[{"contract_address":addr,"entry_point_selector":s,"calldata":cd},{"block_number":block}])
def u256(r,i=0): return int(r[i],16)+(int(r[i+1],16)<<128)

def main():
    block = rpc("starknet_blockNumber", [])
    print("block", block, flush=True)
    pairs = {json.loads(l)["pair"]: json.loads(l) for l in open(os.path.join(OUT,"pairs_raw.jsonl"))}
    meta = json.load(open(os.path.join(OUT,"factory_state.json")))
    prices = json.load(open(os.path.join(OUT,"token_prices.json")))
    vaults = {}
    for p,v in meta["vaults"].items():
        if isinstance(v,list) and v: vaults[p]=v[0]
        elif isinstance(v,str): vaults[p]=v
    def price(t): return prices.get(f"starknet:{t}",{}).get("price")
    S_BAL=sel("balanceOf")

    def fetch(p):
        snap=pairs[p]; v=vaults[p]
        b0=u256(call(snap["token0"],S_BAL,[v],block))
        b1=u256(call(snap["token1"],S_BAL,[v],block))
        return {"pair":p,"vault":v,"vt0":snap["token0"],"vt1":snap["token1"],"vb0":b0,"vb1":b1,
                "d0":int(snap["decimal0"]),"d1":int(snap["decimal1"]),"class":meta["pair_class_hashes"][p]}
    recs=[]
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs=[ex.submit(fetch,p) for p in pairs]
        for i,f in enumerate(as_completed(futs)):
            try: recs.append(f.result())
            except Exception as e: recs.append({"error":repr(e)[:100]})
            if (i+1)%60==0: print(f"  {i+1}/312",flush=True)
    json.dump(recs, open(os.path.join(OUT,"vault_balances.json"),"w"), indent=1)
    tot=0; nz=0; top=[]
    for r in recs:
        if "vb0" not in r: continue
        p0,p1=price(r["vt0"]),price(r["vt1"])
        v=(r["vb0"]/r["d0"]*p0 if p0 else 0)+(r["vb1"]/r["d1"]*p1 if p1 else 0)
        if r["vb0"] or r["vb1"]: nz+=1
        tot+=v
        if v>1: top.append((v,r["pair"],r["vb0"],r["vb1"],r["vt0"],r["vt1"]))
    print(f"vaults nonzero: {nz}/312 | priced fee value: ${tot:.2f}")
    top.sort(reverse=True)
    for v,p,b0,b1,t0,t1 in top[:15]:
        print(f"  ${v:9.2f} {p[:16]} bal0={b0} bal1={b1}")

    # JEDI-P valuation for drainable buggy pairs
    drain=json.load(open(os.path.join(OUT,"drainable_buggy_class.json")))
    S_TS=sel("total_supply"); S_T0=sel("token0"); S_T1=sel("token1"); S_RES=sel("get_reserves")
    lpinfo={}
    for r in drain:
        if int(r["drainable_raw"])==0: continue
        t1=r["token1"]
        if t1 in lpinfo: continue
        try:
            sym=call(t1,sel("symbol"),[],block)
            def f2s(h):
                try:
                    b=bytes.fromhex(h[2:].rjust(64,"0")); return b.rstrip(b"\x00").decode("utf-8","replace")
                except: return "?"
            s=f2s(sym[0]) if sym else "?"
            info={"symbol":s}
            if "JEDI" in s:
                t0=call(t1,S_T0,[],block)[0]; tt1=call(t1,S_T1,[],block)[0]
                res=call(t1,S_RES,[],block); ts=u256(call(t1,S_TS,[],block))
                info.update({"jt0":t0,"jt1":tt1,"jr0":str(u256(res,0)),"jr1":str(u256(res,2)),"jts":str(ts)})
            lpinfo[t1]=info
        except Exception as e:
            lpinfo[t1]={"symbol":"ERR","err":repr(e)[:80]}
    json.dump(lpinfo, open(os.path.join(OUT,"lp_token_info.json"),"w"), indent=1)
    print("\nJEDI-P / token1 info:")
    for t,info in lpinfo.items(): print(" ",t[:16],json.dumps(info)[:220])

if __name__=="__main__":
    main()
