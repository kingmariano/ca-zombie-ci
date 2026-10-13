#!/usr/bin/env python3
"""Price all Velocore V1 pool reserves with DefiLlama coins API."""
import json, urllib.request, time

d = json.load(open("/home/heisenberg/CA/velocore-v1/analysis/pairs_deep.json"))
meta = d["tokens2"]; pairs = d["pairs"]
tokens = sorted(set([p["token0"] for p in pairs] + [p["token1"] for p in pairs]))

def price_batch(addrs):
    ids = ",".join(f"zksync-era:{a.lower()}" for a in addrs)
    url = f"https://coins.llama.fi/prices/current/{ids}"
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read()).get("coins", {})

prices = {}
for i in range(0, len(tokens), 80):
    b = tokens[i:i+80]
    try:
        res = price_batch(b)
        for k,v in res.items():
            prices[k.split(":",1)[1]] = v.get("price")
    except Exception as e:
        print("price err", e)
    time.sleep(0.5)

# fallback known prices
fallback = {
    "0x3355df6d4c9c3035724fd0e3914de96a5a83aaf4": 1.0,  # USDC.e
    "0x5aea5775959fbc2557cc8789bc1bf90a239d9a91": None, # WETH -> price below
    "0x493257fd37edb34451f62edf8d2a0c418852ba4c": 1.0,  # USDT
    "0x2039bb4116b4efc145ec4f0e2ea75012d6c0f181": 1.0,  # BUSD
    "0x8e86e46278518efc1c5ced245cba2c7e3ef11557": 1.0,  # USD+
    "0xbbeb516fb02a01611cbbe0453fe3c580d7281011": None, # WBTC
    "0xb4c6222d6d4f07c39b5a95c2a3bf7b1be2e6bfe3": None, # ?
}
try:
    res = price_batch(["0x5aea5775959fbc2557cc8789bc1bf90a239d9a91","0x493257fd37edb34451f62edf8d2a0c418852ba4c","0xbbeb516fb02a01611cbbe0453fe3c580d7281011"])
    for k,v in res.items(): prices[k.split(":",1)[1]] = v.get("price")
except Exception as e:
    print("price err2", e)

rows=[]
total=0.0
for p in pairs:
    t0,t1 = p["token0"], p["token1"]
    d0=meta.get(t0,{}).get("decimals",18); d1=meta.get(t1,{}).get("decimals",18)
    r0=int(p.get("reserve0") or 0)/10**d0; r1=int(p.get("reserve1") or 0)/10**d1
    pr0=prices.get(t0); pr1=prices.get(t1)
    if pr0 is None: pr0=fallback.get(t0)
    if pr1 is None: pr1=fallback.get(t1)
    v0=(r0*pr0) if pr0 is not None else None
    v1=(r1*pr1) if pr1 is not None else None
    val = (v0 or 0)+(v1 or 0)
    total+=val
    p["usd0"]=round(v0,2) if v0 is not None else None
    p["usd1"]=round(v1,2) if v1 is not None else None
    p["usd"]=round(val,2)
    p["price0"]=pr0; p["price1"]=pr1
    rows.append((val,p["pair"],meta.get(t0,{}).get("symbol"),r0,pr0,meta.get(t1,{}).get("symbol"),r1,pr1,p.get("pool_name")))
rows.sort(key=lambda x:-x[0])
print(f"{'usd':>12} {'pair':44} {'tok0':10} {'r0':>14} {'p0':>10} {'tok1':10} {'r1':>14} {'p1':>10}")
for r in rows[:40]:
    if r[0] <= 0.5: break
    print(f"{r[0]:12.2f} {r[1]:44} {str(r[2])[:10]:10} {r[3]:14.4f} {str(r[4])[:10]:10} {str(r[5])[:10]:10} {r[6]:14.4f} {str(r[7])[:10]:10}")
print("TOTAL priced USD (both sides of all pools):", round(total,2))
json.dump(d, open("/home/heisenberg/CA/velocore-v1/analysis/pairs_priced.json","w"), indent=1)
