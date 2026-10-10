#!/usr/bin/env python3
"""Fine-grained swap-variant optimization for the top nominal pairs (volatile formula)."""
import json, urllib.request, subprocess, os, time

ENDPOINTS=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")

def rpc(method, params, timeout=45, retries=4):
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
    pairs={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pairs_raw.jsonl"))}
    bals={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pair_balances.jsonl"))}
    meta=json.load(open(os.path.join(OUT,"factory_state.json")))
    prices=json.load(open(os.path.join(OUT,"token_prices.json")))
    SPIST="0x6182278e63816ff4080ed07d668f991df6773fd13db0ea10971096033411b11"
    def price(t):
        if t==SPIST: return 1.725e-7
        return prices.get(f"starknet:{t}",{}).get("price")
    fq={r["pair"]:r for r in json.load(open(os.path.join(OUT,"final_quant_v2.json"))) if "pair" in r}
    # top nominal pairs by full_drain_usd
    cands=sorted([r for r in fq.values() if r.get("full_drain_usd")], key=lambda r:-r["full_drain_usd"])[:8]
    print("block",block)
    for rec in cands:
        p=rec["pair"]; s=pairs[p]; b=bals[p]
        r0,r1,b0,b1=b["r0"],b["r1"],b["b0"],b["b1"]
        f=s["fee_tier"]/10000; p0,p1=price(s["token0"]),price(s["token1"])
        d0,d1=int(s["decimal0"]),int(s["decimal1"])
        best=None
        # fine scan over dEff in a wide range (geometric), volatile formula
        import math
        for k in range(0, 4000):
            dEff=int(10**(6+k/100))  # 1e6 .. 1e46
            d1in=int(dEff/(1-f)) if f<1 else dEff
            fee1=d1in-int(d1in*(1-f))
            deff=d1in-fee1
            if deff<=0: continue
            X=r0*deff//(r1+deff)
            S=b0-X-r1-deff
            if not (0<=S<=b1+deff): continue
            v0=X/d0*p0 if p0 else 0.0
            v1=(S-d1in)/d1*p1 if p1 else 0.0
            cap=d1in/d1*p1 if p1 else None
            prof=v0+v1
            if best is None or prof>best["profit_nominal"]:
                best={"delta1":d1in,"delta1_whole":d1in/10**d1,"X":X,"X_whole":X/10**d0,"S":S,"net1":S-d1in,
                      "v0":v0,"v1":v1,"capital_usd":cap,"profit_nominal":prof}
        print(f"== {p[:20]} t1={s['token1'][:12]} stable={s['is_stable']} fee={s['fee_tier']} full_drain_nominal=${rec['full_drain_usd']}")
        if best: print("   best swap:", json.dumps({k:(round(v,6) if isinstance(v,float) else v) for k,v in best.items()}))
        else: print("   no feasible swap window")
    # BROTHER pool depth: find JediSwap pools containing 0x3b405a98c9e795d427
    jp=json.load(open(os.path.join(OUT,"jediswap_pairs.json")))
    BRO="0x3b405a98c9e795d427"  # prefix
    # too heavy to scan all; check known pair 0x2d403244's token0 pools via its own reserves only
    # instead: check DefiLlama price source? skip; report price only
if __name__=="__main__":
    main()
