#!/usr/bin/env python3
"""Detail the flagged excess pairs: symbols, decimals, USD, and skim() simulation."""
import json, time, urllib.request, os

RPC = "https://pulsechain-rpc.publicnode.com"
D = os.path.dirname(os.path.abspath(__file__))
scan = json.load(open(os.path.join(D, "excess_scan.json")))
block = scan["block"]
flagged = []
for r in scan["pairs"]:
    e0 = r.get("excess0"); e1 = r.get("excess1")
    if e0 is None or e1 is None: continue
    if e0 > 0 or e1 > 0:
        flagged.append(r)
print("flagged:", len(flagged))

def rpc_batch(calls, retries=5):
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[c,"latest"]} for i,c in enumerate(calls)]
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                res = json.loads(r.read())
            out=[None]*len(calls)
            for item in res:
                out[item["id"]] = item.get("result", item.get("error"))
            return out
        except Exception:
            time.sleep(2*(a+1))
    return [None]*len(calls)

def enc(sig):
    return sig

def call(to, data, frm=None):
    c={"to":to,"data":data}
    if frm: c["from"]=frm
    return c

def dec_str(h):
    if not h or h=="0x": return None
    try:
        b=bytes.fromhex(h[2:])
        if len(b)<64: return None
        off=int.from_bytes(b[0:32],"big")
        ln=int.from_bytes(b[off:off+32],"big")
        return b[off+32:off+32+ln].decode("utf8","replace")
    except Exception: return None

def dec_uint(h):
    if not h or h=="0x": return None
    try: return int(h,16)
    except Exception: return None

# fetch symbol/decimals for each unique token
tokens=set()
for r in flagged:
    tokens.add(r["token0"]["id"]); tokens.add(r["token1"]["id"])
calls=[]
toklist=sorted(tokens)
for t in toklist:
    calls.append(call(t,"0x95d89b41"))  # symbol()
    calls.append(call(t,"0x313ce567"))  # decimals()
res=rpc_batch(calls)
meta={}
for i,t in enumerate(toklist):
    meta[t]={"symbol":dec_str(res[2*i]),"decimals":dec_uint(res[2*i+1])}
print(json.dumps(meta, indent=1))

# prices
ids=",".join(f"pulsechain:{t}" for t in toklist)
try:
    with urllib.request.urlopen(f"https://coins.llama.fi/prices/current/{ids}", timeout=30) as r:
        prices=json.loads(r.read())["coins"]
except Exception as e:
    prices={}
    print("price fetch failed", e)

out=[]
for r in flagged:
    e0=r["excess0"]; e1=r["excess1"]
    m0=meta[r["token0"]["id"]]; m1=meta[r["token1"]["id"]]
    d0=m0.get("decimals") or 18; d1=m1.get("decimals") or 18
    p0=prices.get(f'pulsechain:{r["token0"]["id"]}',{}).get("price")
    p1=prices.get(f'pulsechain:{r["token1"]["id"]}',{}).get("price")
    usd0=(e0/10**d0)*(p0 or 0); usd1=(e1/10**d1)*(p1 or 0)
    rec={**r,"sym0":m0.get("symbol"),"sym1":m1.get("symbol"),"dec0":d0,"dec1":d1,
         "price0":p0,"price1":p1,"excess_usd0":usd0,"excess_usd1":usd1,"excess_usd_total":usd0+usd1}
    out.append(rec)

# simulate skim from a random EOA to itself
SIMFROM="0x00000000000000000000000000000000000BeEf1"
calls=[]
for r in out:
    data="0xbc25cf77"+"0"*24+SIMFROM[2:].lower()  # skim(address)
    calls.append(call(r["pair"],data,frm=SIMFROM))
res=rpc_batch(calls)
for r,h in zip(out,res):
    ok = h is not None and (isinstance(h,str) and h.startswith("0x"))
    r["skim_sim_ok"]=bool(ok)
    if not ok: r["skim_sim_err"]=str(h)[:160]

out.sort(key=lambda x:x["excess_usd_total"], reverse=True)
json.dump({"block":block,"flagged":out}, open(os.path.join(D,"excess_detail.json"),"w"), indent=1)
print(f"{'pair':44s} {'sym0':12s} {'sym1':12s} {'ex0':>22s} {'ex1':>22s} {'usd':>12s} skim")
for r in out:
    print(f"{r['pair']:44s} {str(r['sym0'])[:12]:12s} {str(r['sym1'])[:12]:12s} {r['excess0']:22d} {r['excess1']:22d} {r['excess_usd_total']:12.2f} {r['skim_sim_ok']}")
