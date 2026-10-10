#!/usr/bin/env python3
"""Final E-U quantification for the StarkDeFi pre-fix skim class.

- drainable pairs: free steal (b0-r1) and full drain via donation d = r1+b1-b0
- swap-needed pairs: binary-search minimal token1 input via live get_amount_out
Feasibility: donation/swap capital cost vs profit (flash fee 0.05% assumed).
"""
import json, urllib.request, subprocess, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")
BUG="0xaef408ec73c83edbc42d00af164ae8073404aa665b9895041c705c871809f9"
SPIST="0x6182278e63816ff4080ed07d668f991df6773fd13db0ea10971096033411b11"
SPIST_PX=1.725e-7
FLASH_FEE=0.0005

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
    pairs={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pairs_raw.jsonl"))}
    bals={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pair_balances.jsonl"))}
    meta=json.load(open(os.path.join(OUT,"factory_state.json")))
    chs=meta["pair_class_hashes"]
    prices=json.load(open(os.path.join(OUT,"token_prices.json")))
    def price(t):
        if t==SPIST: return SPIST_PX
        return prices.get(f"starknet:{t}",{}).get("price")

    buggy=[p for p in pairs if chs.get(p)==BUG]
    print("buggy pairs:",len(buggy))
    S_GAO=sel("get_amount_out")

    def analyze(p):
        s=pairs[p]; b=bals[p]
        d0=int(s["decimal0"]); d1=int(s["decimal1"])
        r0,r1,b0,b1=b["r0"],b["r1"],b["b0"],b["b1"]
        p0,p1=price(s["token0"]),price(s["token1"])
        rec={"pair":p,"token0":s["token0"],"token1":s["token1"],"d0":d0,"d1":d1,
             "r0":r0,"r1":r1,"b0":b0,"b1":b1,"stable":s["is_stable"],"fee_tier":s["fee_tier"],
             "p0":p0,"p1":p1}
        # free steal
        S0=max(0,min(b0-r1,b1))
        rec["free_steal_raw"]=str(S0)
        rec["free_steal_usd"]= (S0/d1*p1) if (p1 and S0>0) else 0.0
        # full drain donation
        d=max(0,(r1+b1)-b0)
        rec["donation_raw"]=str(d)
        rec["donation_usd"]= (d/d0*p0) if p0 else None
        rec["full_drain_raw"]=str(b1)
        rec["full_drain_usd"]= (b1/d1*p1) if p1 else None
        # feasibility of full drain: donation value small + profit > flash fee
        feas=False; net=None
        if rec["full_drain_usd"] and rec["donation_usd"] is not None:
            cost=rec["donation_usd"]*FLASH_FEE
            net=rec["full_drain_usd"]-cost
            feas = net>0 and rec["donation_usd"]<5_000_000
        elif rec["full_drain_usd"] and rec["donation_usd"] is None and d==0:
            feas=True; net=rec["full_drain_usd"]
        rec["full_drain_feasible"]=feas; rec["full_drain_net_usd"]=net
        # swap variant (only if free steal == 0 and not drainable)
        rec["swap_required_raw"]=None; rec["swap_profit_usd"]=None
        if b0<=r1 and s["is_stable"]==False:
            lo,hi=1,10**32
            ok=None
            for _ in range(90):
                mid=(lo+hi)//2
                try:
                    x=u256(call(p,S_GAO,[s["token1"],hex(mid),],block))
                except Exception:
                    x=None
                if x is None: break
                fee1=mid*s["fee_tier"]//10000
                r1p=r1+mid-fee1
                if (r0-x) <= 2*r1p and (r0-x)>=0:
                    ok=(mid,x,fee1); hi=mid
                else:
                    lo=mid+1
                if hi-lo<=1: break
            if ok:
                mid,x,fee1=ok
                S=r0-x-r1-(mid-fee1)
                if 0<=S<=r1+(mid-fee1):
                    profit0=x/d0*p0 if p0 else None
                    profit1=(S-mid)/d1*p1 if p1 else None
                    cap=mid/d1*p1 if p1 else None
                    rec["swap_required_raw"]=str(mid)
                    rec["swap_profit_token0_raw"]=str(x)
                    rec["swap_profit_token1_net_raw"]=str(S-mid)
                    rec["swap_capital_usd"]=cap
                    rec["swap_profit_usd"]=( (profit0 or 0)+(profit1 or 0) ) if (profit0 is not None or profit1 is not None) else None
        return rec

    recs=[]
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs=[ex.submit(analyze,p) for p in buggy]
        for i,f in enumerate(as_completed(futs)):
            try: recs.append(f.result())
            except Exception as e: recs.append({"pair":"?","error":repr(e)[:120]})
            if (i+1)%20==0: print("  ",i+1,"/",len(buggy),flush=True)
    recs.sort(key=lambda r:-(r.get("free_steal_usd") or 0)-(r.get("full_drain_usd") or 0))
    json.dump(recs,open(os.path.join(OUT,"final_quant.json"),"w"),indent=1)

    # totals
    free_usd=sum(r.get("free_steal_usd") or 0 for r in recs)
    drain_usd=sum(r.get("full_drain_usd") or 0 for r in recs)
    feas_usd=sum(r.get("full_drain_net_usd") or 0 for r in recs if r.get("full_drain_feasible"))
    spist_raw=sum(int(r["full_drain_raw"]) for r in recs if r["token1"]==SPIST)
    print(f"free steal total USD: {free_usd:.6f}")
    print(f"full-drain nominal USD (all priced): {drain_usd:.4f}")
    print(f"feasible full-drain net USD: {feas_usd:.4f}")
    print(f"SPIST drain raw total: {spist_raw/1e18:.1f} SPIST  (=${spist_raw/1e18*SPIST_PX:.2f})")
    n_feas=[r["pair"] for r in recs if r.get("full_drain_feasible")]
    print("feasible pairs:",len(n_feas))
    for r in recs:
        if r.get("full_drain_feasible"):
            print(f"  FEAS {r['pair'][:16]} drain1={int(r['full_drain_raw'])/r['d1']:.6g} (${r['full_drain_usd']:.4f}) donation={int(r['donation_raw'])/r['d0']:.6g} (${r['donation_usd'] if r['donation_usd'] is None else round(r['donation_usd'],2)})")
    print("\nswap-needed summary (top by profit):")
    sw=[r for r in recs if r.get("swap_required_raw")]
    sw.sort(key=lambda r:-(r.get("swap_profit_usd") or -1))
    for r in sw[:12]:
        print(f"  {r['pair'][:16]} t1={r['token1'][:12]} req={int(r['swap_required_raw'])/r['d1']:.6g} capUSD={r['swap_capital_usd']} profitUSD={r['swap_profit_usd']}")
    print("swap pairs modeled:",len(sw))

if __name__=="__main__":
    main()
