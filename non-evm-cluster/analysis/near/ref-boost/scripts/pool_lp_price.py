#!/usr/bin/env python3
"""Fetch pool data for given pool ids from v2.ref-finance.near and compute LP token USD price.
Usage: pool_lp_price.py <pool_id> [<pool_id> ...]
Outputs dumps/pool_lp_prices.json and prints LP prices.
"""
import base64, json, sys, time, urllib.request
RPC="https://rpc.mainnet.near.org"
def rpc_call(acct, method, args):
    for i in range(5):
        try:
            ab=base64.b64encode(json.dumps(args).encode()).decode()
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":"query","params":{"request_type":"call_function","account_id":acct,"method_name":method,"args_base64":ab,"finality":"final"}}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=60) as r: d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:200])
            raw=bytes(d["result"].get("result",[]))
            return json.loads(raw.decode()), d["result"].get("block_height")
        except Exception as e:
            err=e; time.sleep(8*(i+1))
    raise RuntimeError(str(err))
def prices(tokens):
    # batch in chunks of 50
    out={}
    for i in range(0,len(tokens),50):
        chunk=tokens[i:i+50]
        url="https://coins.llama.fi/prices/current/"+",".join(f"near:{t}" for t in chunk)
        with urllib.request.urlopen(url,timeout=30) as r:
            d=json.loads(r.read())
        for k,v in d.get("coins",{}).items():
            out[k.replace("near:","")]=v
        time.sleep(1)
    return out
pool_ids=[int(x) for x in sys.argv[1:]]
pool_data={}
for pid in pool_ids:
    try:
        p,bh=rpc_call("v2.ref-finance.near","get_pool",{"pool_id":pid})
        pool_data[pid]=p
        print(f"pool {pid}: kind={p.get('pool_kind')} tokens={p.get('token_account_ids')} shares={p.get('shares_total_supply')} block={bh}", flush=True)
    except Exception as e:
        print(f"pool {pid}: ERR {e}", flush=True)
    time.sleep(2.5)
all_tokens=sorted({t for p in pool_data.values() for t in p.get("token_account_ids",[])})
pr=prices(all_tokens)
print("priced", len([t for t in all_tokens if t in pr]), "of", len(all_tokens))
lp_prices={}
for pid,p in pool_data.items():
    toks=p.get("token_account_ids",[]); amts=[int(a) for a in p.get("amounts",[])]
    shares=int(p.get("shares_total_supply","0"))
    if shares==0: 
        lp_prices[pid]=None; continue
    tvl=0; missing=[]
    for t,a in zip(toks,amts):
        pi=pr.get(t)
        if pi: tvl += a/10**pi["decimals"]*pi["price"]
        else: missing.append(t)
    lp_prices[pid]={"lp_usd": tvl/shares, "tvl_usd": tvl, "missing": missing, "shares": shares}
json.dump({"pool_data": pool_data, "lp_prices": lp_prices}, open("dumps/pool_lp_prices.json","w"), indent=1)
print(json.dumps(lp_prices, indent=1)[:4000])
