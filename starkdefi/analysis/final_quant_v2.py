#!/usr/bin/env python3
"""Corrected final E-U quantification (v2)."""
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
    # non-quiet pairs
    for p in buggy:
        b=bals[p]; s=pairs[p]
        if b["b0"]!=b["r0"] or b["b1"]!=b["r1"]:
            print("NON-QUIET",p[:18],"r0",b["r0"],"b0",b["b0"],"r1",b["r1"],"b1",b["b1"],"class",chs[p][:12])
    S_GAO=sel("get_amount_out")

    def analyze(p):
        s=pairs[p]; b=bals[p]
        d0=int(s["decimal0"]); d1=int(s["decimal1"])
        r0,r1,b0,b1=b["r0"],b["r1"],b["b0"],b["b1"]
        p0,p1=price(s["token0"]),price(s["token1"])
        rec={"pair":p,"token0":s["token0"],"token1":s["token1"],"d0":d0,"d1":d1,
             "r0":r0,"r1":r1,"b0":b0,"b1":b1,"stable":s["is_stable"],"fee_tier":s["fee_tier"],
             "p0":p0,"p1":p1,"fee_rate":s["fee_tier"]/10000}
        # 1) free steal
        S=b0-r1
        free = S if 0<S<=b1 else 0
        rec["free_steal_raw"]=str(free)
        rec["free_steal_usd"]= round(free/d1*p1,6) if (p1 and free>0) else 0.0
        # 2) donation full drain
        d=r1+b1-b0
        rec["donation_raw"]=str(d)
        rec["full_drain_raw"]=str(b1)
        if p1: rec["full_drain_usd"]=round(b1/d1*p1,6)
        else: rec["full_drain_usd"]=None
        feas=False; net=None
        if d>=0 and rec["full_drain_usd"]:
            cap=(d/d0*p0) if p0 else None
            rec["donation_usd"]=cap
            if cap is not None:
                net=rec["full_drain_usd"]-cap*FLASH_FEE
                feas=net>0 and cap<5_000_000
            else:
                feas=None  # unknown token0 price
            rec["full_drain_net_usd"]=net
        rec["donation_feasible"]=feas
        # 3) swap variant: X = r0*dEff/(r1+dEff) (volatile); scan d log-spaced
        best=None
        if s["is_stable"]==False:
            f=s["fee_tier"]/10000
            import math
            cand=set()
            for k in range(0,140):
                cand.add(int(10**(k/10)))
            for d1in in sorted(cand):
                fee1=int(d1in*f); deff=d1in-fee1
                if deff<=0: continue
                X=r0*deff//(r1+deff)
                Sp=b0-X-r1-deff
                if 0<=Sp<=b1+deff:
                    net0=X; net1=Sp-d1in
                    # value
                    v0=net0/d0*p0 if p0 else None
                    v1=net1/d1*p1 if p1 else None
                    if v0 is None and v1 is None: continue
                    val=(v0 or 0)+(v1 or 0)
                    cap=d1in/d1*p1 if p1 else None
                    prof=val-(cap*FLASH_FEE if cap else 0)
                    if best is None or prof>best["profit_usd"]:
                        best={"delta1_raw":d1in,"X_raw":X,"net1_raw":net1,"profit_usd":round(prof,6),
                              "capital_usd":round(cap,2) if cap else None,"val0":round(v0,6) if v0 else None,"val1":round(v1,6) if v1 else None}
        rec["swap_best"]=best
        return rec

    recs=[]
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs=[ex.submit(analyze,p) for p in buggy]
        for i,f in enumerate(as_completed(futs)):
            try: recs.append(f.result())
            except Exception as e: recs.append({"pair":"?","error":repr(e)[:120]})
    json.dump(recs,open(os.path.join(OUT,"final_quant_v2.json"),"w"),indent=1)
    free_usd=sum(r.get("free_steal_usd") or 0 for r in recs)
    print(f"\nfree steal total USD: {free_usd:.6f} across {sum(1 for r in recs if int(r.get('free_steal_raw','0'))>0)} pairs")
    fd=[r for r in recs if r.get("donation_feasible")]
    print("donation-feasible pairs:",len(fd))
    for r in fd[:20]:
        print(f"  {r['pair'][:16]} drain=${r['full_drain_usd']} donation={int(r['donation_raw'])/r['d0']:.6g} (${r['donation_usd']}) net=${r['full_drain_net_usd']}")
    sw=[r for r in recs if r.get("swap_best")]
    sw.sort(key=lambda r:-r["swap_best"]["profit_usd"])
    print("swap-profitable pairs:",sum(1 for r in sw if r["swap_best"]["profit_usd"]>0))
    for r in sw[:15]:
        sb=r["swap_best"]
        print(f"  {r['pair'][:16]} t1={r['token1'][:12]} delta1={sb['delta1_raw']/r['d1']:.6g} capUSD={sb['capital_usd']} profit=${sb['profit_usd']} (v0={sb['val0']},v1={sb['val1']})")
    # headline: sum of best feasible per pair (choose max of free/donation/swap)
    tot=0
    for r in recs:
        opts=[r.get("free_steal_usd") or 0]
        if r.get("donation_feasible"): opts.append(r["full_drain_net_usd"] or 0)
        if r.get("swap_best") and (r["swap_best"]["profit_usd"] or 0)>0: opts.append(r["swap_best"]["profit_usd"])
        tot+=max(opts)
    print(f"\nHEADLINE E-U (best feasible per pair): ${tot:.4f}")
    # nominal (capital-free) upper bound
    nom=sum((r.get("full_drain_usd") or 0) for r in recs)
    print(f"NOMINAL full-drain (ignoring capital): ${nom:.2f}")

if __name__=="__main__":
    main()
