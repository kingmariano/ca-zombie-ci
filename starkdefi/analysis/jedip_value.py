#!/usr/bin/env python3
"""Value JEDI-P tokens drained from StarkDeFi buggy pairs (correct layout r0,r1,ts)."""
import json, urllib.request, subprocess, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")

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
def f2s(h):
    try:
        b=bytes.fromhex(h[2:].rjust(64,"0")); return b.rstrip(b"\x00").decode("utf-8","replace")
    except: return "?"

def main():
    block=rpc("starknet_blockNumber",[])
    print("block",block,flush=True)
    drain=json.load(open(os.path.join(OUT,"drainable_buggy_class.json")))
    prices=json.load(open(os.path.join(OUT,"token_prices.json")))
    def price(t): return prices.get(f"starknet:{t}",{}).get("price")
    S_T0=sel("token0"); S_T1=sel("token1"); S_RES=sel("get_reserves"); S_TS1=sel("total_supply"); S_TS2=sel("totalSupply")
    S_DEC=sel("decimals"); S_SYM=sel("symbol"); S_NAME=sel("name")
    spist_pools=json.load(open(os.path.join(OUT,"spist_pools.json")))
    spist_px=1.725e-7  # median implied

    jp={}  # address -> info
    rows=[]
    for r in drain:
        if int(r["drainable_raw"])==0: continue
        t1=r["token1"]
        if t1 not in jp:
            info={"token":t1}
            try: info["symbol"]=f2s(call(t1,S_SYM,[],block)[0])
            except Exception: info["symbol"]="ERR"
            try:
                info["t0"]=call(t1,S_T0,[],block)[0]; info["t1"]=call(t1,S_T1,[],block)[0]
                res=call(t1,S_RES,[],block); info["r0"]=u256(res,0); info["r1"]=u256(res,2)
                ts=None
                for s in (S_TS1,S_TS2):
                    try: ts=u256(call(t1,s,[],block)); break
                    except Exception: pass
                info["lp_supply"]=ts
                for side in ("t0","t1"):
                    tok=info[side]
                    try:
                        info[side+"_dec"]=int(call(tok,S_DEC,[],block)[0],16)
                        info[side+"_sym"]=f2s(call(tok,S_SYM,[],block)[0])
                    except Exception:
                        info[side+"_dec"]=18; info[side+"_sym"]="?"
            except Exception as e:
                info["err"]=repr(e)[:80]
            jp[t1]=info
        info=jp[t1]
        # drained share
        D=int(r["drainable_raw"])
        share = D/info["lp_supply"] if info.get("lp_supply") else None
        # underlying value
        und_usd=None
        if info.get("r0") is not None and info.get("lp_supply"):
            v=0.0; unknown=False
            for side in ("t0","t1"):
                tok=info[side]; dec=info[side+"_dec"]; res=info["r0"] if side=="t0" else info["r1"]
                p=price(tok)
                if p is None and tok=="0x6182278e63816ff4080ed07d668f991df6773fd13db0ea10971096033411b11":
                    p=spist_px
                if p is None: unknown=True
                else: v += res/10**dec*p
            und_usd = None if unknown else v
        drain_usd = (share*und_usd) if (share is not None and und_usd is not None) else None
        rows.append({"pair":r["pair"],"token1":t1,"drain_raw":str(D),"share":share,"underlying_usd":und_usd,"drain_usd":drain_usd,
                     "lp_supply":info.get("lp_supply"),"r0":info.get("r0"),"r1":info.get("r1"),
                     "t0":info.get("t0"),"t1":info.get("t1"),"t0_sym":info.get("t0_sym"),"t1_sym":info.get("t1_sym")})
    json.dump(rows,open(os.path.join(OUT,"jedip_drain_values.json"),"w"),indent=1)
    tot=0; tot_known=0
    for r in rows:
        if r["drain_usd"] is not None:
            tot_known+=1; tot+=r["drain_usd"]
        print(f"  pair {r['pair'][:16]} tok1={r['token1'][:14]} drain={int(r['drain_raw'])/1e18:.6g} share={r['share']} underUSD={r['underlying_usd']} drainUSD={r['drain_usd']} t0={r['t0_sym']} t1={r['t1_sym']}")
    print("known-value drains:",tot_known,"TOTAL JEDI-P drain USD:",round(tot,2))
    print(json.dumps({k:{kk:str(vv) for kk,vv in v.items()} for k,v in jp.items()},indent=1)[:3000])

if __name__=="__main__":
    main()
