#!/usr/bin/env python3
"""Finish REF measurements: missing pool LP prices, missing FT balances, USD totals.
Read-only. Merges into dumps/pool_lp_prices.json and writes dumps/ref_final_values.json."""
import base64, json, os, re, time, urllib.request

RPC="https://rpc.mainnet.near.org"
CACHE="dumps/pool_lp_prices.json"

def rpc(m,p,tries=6):
    err=None
    for i in range(tries):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=60) as r: d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:150])
            return d["result"]
        except Exception as e:
            err=e; time.sleep(6*(i+1))
    raise RuntimeError(str(err))

def call(acct, method, args=None):
    ab=base64.b64encode(json.dumps(args or {}).encode()).decode()
    r=rpc("query",{"request_type":"call_function","account_id":acct,"method_name":method,"args_base64":ab,"finality":"final"})
    raw=bytes(r.get("result",[]))
    try: return json.loads(raw.decode()), r.get("block_height")
    except Exception: return None, r.get("block_height")

cache=json.load(open(CACHE)); pools=cache["pool_data"]
missing_pools=[5438,5844,5516,5846,5906,5494,5650,5789,5583,3699,2439,5502,5845]
for pid in missing_pools:
    if str(pid) in pools and pools[str(pid)]: continue
    try:
        p,bh=call("v2.ref-finance.near","get_pool",{"pool_id":pid})
        if p: pools[str(pid)]=p; print(f"pool {pid} fetched block={bh}", flush=True)
    except Exception as e:
        print(f"pool {pid} ERR {e}", flush=True)
    time.sleep(2)
json.dump(cache, open(CACHE,"w"), indent=1)

def price_tokens(tokens):
    out={}
    toks=[t for t in tokens if t]
    for i in range(0,len(toks),50):
        chunk=toks[i:i+50]
        try:
            with urllib.request.urlopen("https://coins.llama.fi/prices/current/"+",".join(f"near:{t}" for t in chunk),timeout=30) as r:
                d=json.loads(r.read())
            for k,v in d.get("coins",{}).items(): out[k.replace("near:","")]=v
        except Exception as e: print("price err", e)
        time.sleep(1)
    return out

# rebuild lp_prices fully from pools
all_tokens=sorted({t for p in pools.values() if p for t in p.get("token_account_ids",[])})
pr=price_tokens(all_tokens)
lp={}
for pid,p in pools.items():
    if not p: continue
    toks=p.get("token_account_ids",[]); amts=[int(a) for a in p.get("amounts",[])]
    shares=int(p.get("shares_total_supply","0"))
    if not shares: continue
    tvl=0; miss=[]
    for t,a in zip(toks,amts):
        pi=pr.get(t)
        if pi: tvl+=a/10**pi["decimals"]*pi["price"]
        else: miss.append(t)
    lp[pid]={"lp_usd":tvl/shares,"tvl_usd":tvl,"missing":miss,"shares":shares}
cache["lp_prices"]=lp
json.dump(cache, open(CACHE,"w"), indent=1)

seeds_v2=json.load(open("dumps/v2.ref-farming.seeds.json"))
seeds_b=json.load(open("dumps/boostfarm.seeds.json"))["result"]
SIMPLE=re.compile(r"^v2\.ref-finance\.near@\d+$")
tot_v2=0; tot_b=0; miss_v2=[]; miss_b=[]
for s,v in seeds_v2.items():
    pid=s.split("@")[1] if "@" in s else None
    x=lp.get(str(pid)) if pid else None
    if x: tot_v2+=int(v["amount"])*x["lp_usd"]
    else: miss_v2.append([s,int(v["amount"])])
for v in seeds_b:
    sid=v["seed_id"]; pid=sid.split("@")[1] if SIMPLE.match(sid) else None
    x=lp.get(str(pid)) if pid else None
    if x: tot_b+=int(v["total_seed_amount"])*x["lp_usd"]
    else: miss_b.append([sid,int(v["total_seed_amount"])])

# FT balances: merge existing dumps + fetch missing
def ft_bal(tok, acct):
    ab=base64.b64encode(json.dumps({"account_id":acct}).encode()).decode()
    r=rpc("query",{"request_type":"call_function","account_id":tok,"method_name":"ft_balance_of","args_base64":ab,"finality":"final"})
    raw=bytes(r.get("result",[]))
    try: return json.loads(raw.decode())
    except Exception: return None

existing_v2=json.load(open("dumps/v2.ref-farming.near.ft_balances.json"))["balances"]
existing_b=json.load(open("dumps/boostfarm.ref-labs.near.ft_balances.json"))["balances"]
def refresh(existing, acct):
    out={}
    for tok, rec in existing.items():
        val = rec.get("raw")
        if rec.get("error") or val is None:
            try:
                val=ft_bal(tok, acct); print(f"{acct} retry {tok} -> {val}", flush=True)
            except Exception as e:
                print(f"{acct} retry {tok} ERR {e}", flush=True); val=None
            time.sleep(2)
        out[tok]=val
    return out
bal_v2=refresh(existing_v2, "v2.ref-farming.near")
bal_b=refresh(existing_b, "boostfarm.ref-labs.near")
json.dump({"v2":bal_v2,"boost":bal_b}, open("dumps/farms_ft_balances_final.json","w"), indent=1)

# prices for all tokens
pr2=price_tokens(list(bal_v2.keys())+list(bal_b.keys()))
def usd(bals):
    out={}; tot=0.0
    for t,raw in bals.items():
        if raw is None: continue
        pi=pr2.get(t)
        if not pi: 
            out[t]={"raw":str(raw),"usd":None}; continue
        v=int(raw)/10**pi["decimals"]*pi["price"]
        out[t]={"raw":str(raw),"amount":int(raw)/10**pi["decimals"],"price":pi["price"],"usd":v}
        tot+=v
    return out, tot
v2_usddetail, v2_ft_usd = usd(bal_v2)
b_usddetail, b_ft_usd = usd(bal_b)
out={
 "block_pools_fetched_until": 219335000,
 "v2_farm": {"staked_lp_usd":tot_v2, "reward_ft_balances_usd":v2_ft_usd, "uncovered_seeds":miss_v2, "ft":[v2_usddetail]},
 "boostfarm": {"staked_lp_usd":tot_b, "reward_ft_balances_usd":b_ft_usd, "uncovered_seeds":miss_b, "ft":[b_usddetail]},
 "tokens_priced": {k:{"price":v["price"],"decimals":v["decimals"],"ts":v.get("timestamp")} for k,v in pr2.items()},
}
json.dump(out, open("dumps/ref_final_values.json","w"), indent=1)
print(json.dumps({"v2_staked_lp_usd":tot_v2,"v2_ft_usd":v2_ft_usd,"boost_staked_lp_usd":tot_b,"boost_ft_usd":b_ft_usd,"uncovered_v2":len(miss_v2),"uncovered_boost":len(miss_b)}, indent=1))
for t,d in sorted(v2_usddetail.items(), key=lambda x:-(x[1]["usd"] or 0))[:12]:
    print(f"  v2 {t:44s} {d}")
for t,d in sorted(b_usddetail.items(), key=lambda x:-(x[1]["usd"] or 0))[:12]:
    print(f"  bf {t:44s} {d}")
