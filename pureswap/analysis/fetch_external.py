#!/usr/bin/env python3
"""Fetch reserves/vol for external MX pairs (Pancake, ApeSwap, BakerySwap, BiSwap...)."""
import json, os, urllib.request, time

RPC = os.environ.get("RPC_BSC", "https://bsc-rpc.publicnode.com")

def call(to, data, retries=5):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            d = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
            if "result" in d:
                return d["result"]
        except Exception:
            pass
        time.sleep(1.2 * (i + 1))
    return None

PAIRS = [
    ("Pancake", "0x7b14d6981e101cf3445a3e4991f6c5680b79d10f"),
    ("Pancake", "0x41f049d990d38305504631c9835f6f856bf1ba67"),
    ("Pancake", "0x5332e9fde6ce5c7ef71e04feeffe3faad60f2e2a"),
    ("ApeSwap", "0x7c81007cbf51561b8606a7d4410eb9614bae7ccc"),
    ("BakerySwap", "0x707e4e8745e87397922e27aec4718e6fee12f92a"),
]
MX = "0x9f882567a62a5560d147d64871776eea72df41d3"
out = []
for dex, p in PAIRS:
    t0 = call(p, "0x0dfe1681"); t1 = call(p, "0xd21220a7")
    r = call(p, "0x0902f1ac"); ts = call(p, "0x18160ddd")
    t0 = "0x" + t0[-40:] if t0 else None
    t1 = "0x" + t1[-40:] if t1 else None
    res = (int(r[2:66], 16), int(r[66:130], 16)) if r and r != "0x" else None
    ts = int(ts, 16) if ts and ts != "0x" else None
    b_mx = call(MX, "0x70a08231" + "0" * 24 + p) if t0 == MX or t1 == MX else None
    rec = {"dex": dex, "pair": p, "token0": t0, "token1": t1, "res0": res[0] if res else None,
           "res1": res[1] if res else None, "totalSupply": ts,
           "mx_balance": int(b_mx, 16) if b_mx else None}
    out.append(rec)
    print(json.dumps(rec))
json.dump(out, open(os.path.join(os.path.dirname(__file__), "external-pairs.json"), "w"), indent=1)
