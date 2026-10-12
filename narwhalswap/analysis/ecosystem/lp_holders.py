#!/usr/bin/env python3
"""LP holder analysis from transfer checkpoint (balance tracking) + current balanceOf verify."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr

CKPT = "/home/heisenberg/CA/narwhalswap/analysis/ecosystem/lp_transfers_snapshot.json"
state = json.load(open(CKPT))
logs = state["logs"]
print("logs loaded:", len(logs), "scanned until block", state["done_until"])
LPS = {"0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2": "LP_NAR_WBNB",
       "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957": "LP_WBNB_THUGS",
       "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3": "LP_WBNB_BUSD",
       "0x00eda48b05a72e518033c78ad8c140109136fe23": "LP_IN_LP_NARWBNB",
       "0x8b1bbfaf50551d8427bc24beecd3406cdcef48b8": "LP_IN_LP_THUGS",
       "0x6166911e31c55de58a32cd2abe379fe4382aec9d": "LP_IN_LP_BUSD"}
# balance tracking (log-scan derived)
bal = {}
for l in logs:
    a = l["address"].lower()
    if a not in LPS: continue
    topics = l["topics"]
    frm = "0x" + topics[1][-40:]
    to = "0x" + topics[2][-40:]
    v = int(l["data"], 16) if l["data"] and l["data"] != "0x" else 0
    bal[(a, frm)] = bal.get((a, frm), 0) - v
    bal[(a, to)] = bal.get((a, to), 0) + v
holders = {}
for (a, addr), v in bal.items():
    if v > 0: holders.setdefault(a, []).append((addr, v))
for a, name in LPS.items():
    hs = sorted(holders.get(a, []), key=lambda x: -x[1])
    print(f"\n== {name} {a}: derived holders {len(hs)}")
    for addr, v in hs[:10]:
        print(f"   {addr} {v/1e18:.6f}")
# current balances verify (batch)
allpairs = [(a, addr) for a, lst in holders.items() for addr, _ in lst]
print("\ntotal holder-address pairs:", len(allpairs))
res = []
CH = 60
for i in range(0, len(allpairs), CH):
    part = allpairs[i:i+CH]
    batch = [("eth_call", [{"to": a, "data": sel("balanceOf(address)") + enc_addr(addr)}, "latest"]) for a, addr in part]
    try:
        res.extend(rpc_batch(batch, timeout=120))
    except Exception as e:
        print("batch failed at", i, str(e)[:80]); res.extend([None]*len(part))
cur = {}
for (a, addr), r in zip(allpairs, res):
    v = hexint(r) if r else 0
    if v: cur.setdefault(a, []).append((addr, v))
out = {}
for a, name in LPS.items():
    hs = sorted(cur.get(a, []), key=lambda x: -x[1])
    out[name] = [{"addr": x, "balance_wei": str(v)} for x, v in hs]
    print(f"\n== {name}: current holders with balance {(len(hs))}")
    for addr, v in hs[:15]:
        print(f"   {addr} {v/1e18:.6f}")
json.dump({"scanned_until": state["done_until"], "holders": out}, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/lp_holders.json", "w"), indent=1)
print("saved lp_holders.json")
