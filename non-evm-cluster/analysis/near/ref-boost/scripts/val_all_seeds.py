#!/usr/bin/env python3
"""Value all seed LP positions in v2.ref-farming.near and boostfarm.ref-labs.near.
Fetches get_pool for every pool id referenced by seeds, merges with cached pool data,
prices tokens via DefiLlama, computes LP USD, and totals per farm. Read-only."""
import base64, json, os, re, time, urllib.request

RPC="https://rpc.mainnet.near.org"
CACHE="dumps/pool_lp_prices.json"

def rpc_call(acct, method, args, tries=4):
    err=None
    for i in range(tries):
        try:
            ab=base64.b64encode(json.dumps(args).encode()).decode()
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":"query","params":{"request_type":"call_function","account_id":acct,"method_name":method,"args_base64":ab,"finality":"final"}}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=60) as r: d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:150])
            raw=bytes(d["result"].get("result",[]))
            return json.loads(raw.decode()), d["result"].get("block_height")
        except Exception as e:
            err=e; time.sleep(5*(i+1))
    raise RuntimeError(str(err))

cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {"pool_data":{}, "lp_prices":{}}
pool_data = cache.get("pool_data", {})
seeds_v2 = json.load(open("dumps/v2.ref-farming.seeds.json"))
seeds_b = json.load(open("dumps/boostfarm.seeds.json"))["result"]
SIMPLE = re.compile(r"^v2\.ref-finance\.near@\d+$")
pids = set()
for sid in seeds_v2:
    if SIMPLE.match(sid): pids.add(int(sid.split("@")[1]))
nonsimple_b = []
for v in seeds_b:
    if SIMPLE.match(v["seed_id"]): pids.add(int(v["seed_id"].split("@")[1]))
    else: nonsimple_b.append([v["seed_id"], v["total_seed_amount"]])
pids = sorted(pids)
print("unique pools:", len(pids))
for pid in pids:
    if str(pid) in pool_data and pool_data[str(pid)]:
        continue
    try:
        p,bh = rpc_call("v2.ref-finance.near","get_pool",{"pool_id":pid})
        pool_data[str(pid)] = p
        json.dump({"pool_data":pool_data,"lp_prices":cache.get("lp_prices",{})}, open(CACHE,"w"), indent=1)
        print(f"fetched pool {pid} kind={p.get('pool_kind')} block={bh}", flush=True)
    except Exception as e:
        print(f"pool {pid} ERR {e}", flush=True)
    time.sleep(1.2)

def prices(tokens):
    out={}
    for i in range(0,len(tokens),50):
        chunk=tokens[i:i+50]
        try:
            with urllib.request.urlopen("https://coins.llama.fi/prices/current/"+",".join(f"near:{t}" for t in chunk),timeout=30) as r:
                d=json.loads(r.read())
            for k,v in d.get("coins",{}).items(): out[k.replace("near:","")]=v
        except Exception as e:
            print("price err", e)
        time.sleep(1)
    return out

all_tokens=sorted({t for p in pool_data.values() if p for t in p.get("token_account_ids",[])})
pr=prices(all_tokens)
lp_prices={}
for pid,p in pool_data.items():
    if not p: continue
    toks=p.get("token_account_ids",[]); amts=[int(a) for a in p.get("amounts",[])]
    shares=int(p.get("shares_total_supply","0"))
    if not shares: continue
    tvl=0.0; missing=[]
    for t,a in zip(toks,amts):
        pi=pr.get(t)
        if pi: tvl += a/10**pi["decimals"]*pi["price"]
        else: missing.append(t)
    lp_prices[pid]={"lp_usd":tvl/shares,"tvl_usd":tvl,"missing":missing,"shares":shares,"tokens":toks,"prices_ts":pr.get(toks[0],{}).get("timestamp") if toks else None}
json.dump({"pool_data":pool_data,"lp_prices":lp_prices}, open(CACHE,"w"), indent=1)

def val(amount,pid):
    v=lp_prices.get(str(pid))
    return None if not v else int(amount)*v["lp_usd"]
tot_v2=0;tot_b=0;miss_v2=[];miss_b=[]
for sid,v in seeds_v2.items():
    pid = sid.split("@")[1] if "@" in sid else None
    x=val(v["amount"],pid)
    if x is None: miss_v2.append([sid,int(v["amount"])])
    else: tot_v2+=x
for v in seeds_b:
    sid=v["seed_id"]; pid = sid.split("@")[1] if SIMPLE.match(sid) else None
    x=val(v["total_seed_amount"],pid)
    if x is None: miss_b.append([sid,int(v["total_seed_amount"])])
    else: tot_b+=x
out={"block_pools_fetched_at":max((int(bh) for bh in [219328573])),
     "v2_farm_staked_lp_usd":tot_v2,"boostfarm_staked_lp_usd":tot_b,
     "uncovered_v2":miss_v2,"uncovered_boost":miss_b, "nonsimple_boost_seeds":nonsimple_b,
     "n_pools":len(pool_data)}
json.dump(out,open("dumps/lp_value_full.json","w"),indent=1)
print(json.dumps(out,indent=1)[:3000])
