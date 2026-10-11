#!/usr/bin/env python3
"""Read staking_token() for all 37 gauge assets; fetch DefiLlama prices; compute value."""
import json, os, urllib.request

RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL")
def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"python-research"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["result"]
def batch(calls):
    out=[]
    for i in range(0,len(calls),10):
        chunk=calls[i:i+10]
        body=[{"jsonrpc":"2.0","id":i+j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        req=urllib.request.Request(RPC,data=json.dumps(body).encode(),
            headers={"Content-Type":"application/json","User-Agent":"python-research"})
        with urllib.request.urlopen(req,timeout=120) as r:
            res=json.load(r)
        if isinstance(res,dict): res=[res]
        m={x["id"]:x.get("result") for x in res}
        out += [m.get(i+j) for j in range(len(chunk))]
    return out
def u(w): return int(w,16) if w and w!="0x" else 0
def ad(w): return "0x"+w[-40:] if w and len(w)>=40 else None

SEL_STAKING_TOKEN="0x2dc7d74c"
SEL_NAME="0x06fdde03"
SEL_SYMBOL="0x95d89b41"

st = json.load(open("live_balances.json"))
positions = st["positions"]
blk = int(rpc("eth_blockNumber",[]),16)

# read staking_token for each gauge
calls=[("eth_call",[{"to":p["cvgSdt"],"data":SEL_STAKING_TOKEN},"latest"]) for p in positions]
res=batch(calls)
tokens=set()
for p,r in zip(positions,res):
    p["underlying"]=ad(r) if r and r!="0x" else None
    if p["underlying"]: tokens.add(p["underlying"].lower())

# prices from DefiLlama
prices={}
tl=tokens
url="https://coins.llama.fi/prices/current/"+",".join(f"ethereum:{t}" for t in sorted(tl))
with urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":"python-research"}),timeout=60) as r:
    data=json.load(r)
for k,v in data.get("coins",{}).items():
    prices[k.split(":")[1].lower()]={"price":v.get("price"),"symbol":v.get("symbol"),"decimals":v.get("decimals"),"conf":v.get("confidence")}

total=0.0
rows=[]
for p in positions:
    und=p["underlying"]; amt=p["blackhole_balance"] or 0
    pr=prices.get(und.lower(),{}) if und else {}
    price=pr.get("price") or 0
    val=amt*price/1e18
    total+=val
    rows.append({"name":p["name"],"gauge":p["cvgSdt"],"underlying":und,"symbol":pr.get("symbol"),
                 "amount":str(amt),"price":price,"usd":round(val,2),"conf":pr.get("conf")})
    print(f'{p["name"][:32]:34s} und={und} {str(pr.get("symbol")):18s} amt={amt/1e18:>22.6f} price={price:>10} usd={val:>14,.2f}')
print(f"TOTAL (blackhole balances priced at DefiLlama current): ${total:,.2f}  block={blk}")
json.dump({"block":blk,"rows":rows,"total_usd":round(total,2),"prices":prices},open("pricing.json","w"),indent=1)
