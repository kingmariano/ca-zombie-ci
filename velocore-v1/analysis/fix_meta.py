#!/usr/bin/env python3
"""Fix token metadata decode + classify pools + USD price reserves via DefiLlama."""
import json, urllib.request, time

RPC = "https://mainnet.era.zksync.io"
SEL = {"symbol": "0x95d89b41", "name": "0x06fdde03", "decimals": "0x313ce567"}

def rpc_batch(calls):
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i+1, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                res = json.loads(r.read())
            break
        except Exception:
            if attempt == 4: raise
            time.sleep(2*(attempt+1))
    if isinstance(res, dict): res = [res]
    out = [None]*len(calls)
    for item in res: out[item["id"]-1] = item.get("result")
    return out

def dec_str(h):
    if not h or h == "0x": return None
    try:
        if len(h) > 130:
            ln = int(h[66:130], 16)
            return bytes.fromhex(h[130:130+2*ln]).decode("utf-8","replace")
        return bytes.fromhex(h[2:]).rstrip(b"\x00").decode("utf-8","replace")
    except Exception: return None

def chunked(l,n):
    for i in range(0,len(l),n): yield l[i:i+n]

d = json.load(open("/home/heisenberg/CA/velocore-v1/analysis/pairs_deep.json"))
pairs = d["pairs"]
tokens = set()
for p in pairs: tokens.add(p["token0"]); tokens.add(p["token1"])
tokens = sorted(t for t in tokens if t)
meta = {}
for batch in chunked(tokens, 10):
    syms = rpc_batch([(t, SEL["symbol"]) for t in batch])
    decs = rpc_batch([(t, SEL["decimals"]) for t in batch])
    for t,s,dd in zip(batch,syms,decs):
        meta[t] = {"symbol": dec_str(s), "decimals": int(dd,16) if dd and dd!="0x" else 18}
# pool names
for batch in chunked(pairs, 10):
    names = rpc_batch([(p["pair"], SEL["name"]) for p in batch])
    for p,n in zip(batch,names):
        p["pool_name"] = dec_str(n)
d["tokens2"] = meta
json.dump(d, open("/home/heisenberg/CA/velocore-v1/analysis/pairs_deep.json","w"), indent=1)

print(f"{'pair':44} {'type':10} {'tok0':12} {'r0':>18} {'tok1':12} {'r1':>18}")
rows=[]
for p in pairs:
    t0,t1 = p["token0"],p["token1"]
    s0=meta.get(t0,{}).get("symbol"); s1=meta.get(t1,{}).get("symbol")
    d0=meta.get(t0,{}).get("decimals",18); d1=meta.get(t1,{}).get("decimals",18)
    r0=int(p.get("reserve0") or 0)/10**d0; r1=int(p.get("reserve1") or 0)/10**d1
    if r0>0 or r1>0:
        rows.append((p["pair"],p.get("pool_name") or "?",s0,r0,s1,r1,p.get("stable"),t0,t1,d0,d1))
# print all with values, sorted by combined magnitude is meaningless without prices; print raw
for r in rows:
    print(f"{r[0]:44} {str(r[6]):10} {str(r[2])[:12]:12} {r[3]:18.4f} {str(r[4])[:12]:12} {r[5]:18.4f}")
print("stable pools:", sum(1 for p in pairs if p.get("stable")), "of", len(pairs))
