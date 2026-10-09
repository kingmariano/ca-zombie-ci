#!/usr/bin/env python3
"""Read reserves + metadata for candidate Shido DEX pairs. Read-only."""
import json, urllib.request, sys

RPC = "https://evm.shidoscan.net"
UA = {"User-Agent": "zombie-research/1.0", "Content-Type": "application/json"}

def rpc_batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=30).read())

def dec_str(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], 'big')
            return b[64:64+ln].decode('utf-8', 'replace')
    except Exception:
        pass
    return '?'

def call_once(to, sel):
    r = rpc_batch([("eth_call", [{"to": to, "data": sel}, "latest"])])
    return r[0].get("result")

raw = json.load(open("shido_pair_scan_raw.json"))
pairs = raw["pairs"]

# gather all token addresses
toks = set()
for p in pairs.values():
    toks.add(p["token0"].lower()); toks.add(p["token1"].lower())

meta = {}
for t in sorted(toks):
    sym = call_once(t, "0x95d89b41")
    dec = call_once(t, "0x313ce567")
    meta[t] = {"symbol": dec_str(sym) if sym else '?', "decimals": int(dec, 16) if dec and dec != '0x' else None}
print("token metadata:")
for t, m in meta.items():
    print(f"  {t} {m['symbol']} dec={m['decimals']}")

print("\npair reserves:")
rows = []
for a, p in pairs.items():
    r = call_once(a, "0x0902f1ac")  # getReserves()
    if not r or r == '0x':
        rows.append({"pair": a, "note": "no getReserves"}); print(a, "no getReserves"); continue
    b = bytes.fromhex(r[2:])
    r0 = int.from_bytes(b[0:32], 'big') & ((1 << 112) - 1)
    r1 = int.from_bytes(b[32:64], 'big') & ((1 << 112) - 1)
    t0, t1 = p["token0"].lower(), p["token1"].lower()
    d0, d1 = meta[t0]["decimals"], meta[t1]["decimals"]
    s0, s1 = meta[t0]["symbol"], meta[t1]["symbol"]
    human0 = r0 / (10 ** d0) if d0 else None
    human1 = r1 / (10 ** d1) if d1 else None
    rows.append({"pair": a, "token0": t0, "symbol0": s0, "decimals0": d0,
                 "reserve0": r0, "human0": human0,
                 "token1": t1, "symbol1": s1, "decimals1": d1,
                 "reserve1": r1, "human1": human1})
    print(f"{a} {s0}({human0:,.2f}) / {s1}({human1:,.2f})")
json.dump({"meta": meta, "rows": rows}, open("shido_pair_reserves.json", "w"), indent=1)
