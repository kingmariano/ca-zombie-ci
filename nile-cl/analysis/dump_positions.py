#!/usr/bin/env python3
"""Dump the live (non-empty) Nile CL NFP positions with owners. Read-only, keyless RPC."""
import json, os, time, urllib.request

R = os.environ.get("LINEA_PUBLIC_RPC", "https://linea-rpc.publicnode.com")
NFP = "0xAAA78E8C4241990B4ce159E105dA08129345946A"
HERE = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Mozilla/5.0", "Content-Type": "application/json"}
_id = 0

def batch(calls):
    global _id
    payload = []
    for m, p in calls:
        _id += 1
        payload.append({"jsonrpc": "2.0", "id": _id, "method": m, "params": p})
    body = json.dumps(payload).encode()
    for a in range(5):
        try:
            req = urllib.request.Request(R, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.load(r)
            out = {x["id"]: x.get("result") for x in res}
            time.sleep(0.12)
            return [out.get(i) for i in range(_id - len(calls) + 1, _id + 1)]
        except Exception:
            time.sleep(1.5)
    return [None] * len(calls)

def call_pos(i):
    return ("eth_call", [{"to": NFP, "data": "0x99fbab88" + hex(i)[2:].rjust(64, "0")}, "latest"])

def call_owner(i):
    return ("eth_call", [{"to": NFP, "data": "0x6352211e" + hex(i)[2:].rjust(64, "0")}, "latest"])

total = 8282
live = []
for start in range(1, total + 1, 20):
    chunk = list(range(start, min(start + 20, total + 1)))
    res = batch([call_pos(i) for i in chunk])
    for i, r in zip(chunk, res):
        if not r or len(r) < 2 + 64 * 12:
            continue
        w = [r[2:][k*64:(k+1)*64] for k in range(12)]
        rec = {
            "id": i,
            "token0": "0x" + w[2][-40:],
            "token1": "0x" + w[3][-40:],
            "fee": int(w[4], 16),
            "tickLower": int(w[5], 16) - (1 << 256) if int(w[5], 16) >= (1 << 255) else int(w[5], 16),
            "tickUpper": int(w[6], 16) - (1 << 256) if int(w[6], 16) >= (1 << 255) else int(w[6], 16),
            "liquidity": int(w[7], 16),
            "owed0": int(w[10], 16),
            "owed1": int(w[11], 16),
        }
        if rec["liquidity"] or rec["owed0"] or rec["owed1"]:
            live.append(rec)
    if start % 1000 == 1:
        print(f"scanned {start}/{total}, live {len(live)}", flush=True)

res = batch([call_owner(r["id"]) for r in live])
for r, o in zip(live, res):
    r["owner"] = ("0x" + o[-40:].lower()) if (o and len(o) >= 42) else None

out = {"block_note": "latest at run", "total_supply": total, "live_positions": live}
json.dump(out, open(os.path.join(HERE, "nfp_positions.json"), "w"), indent=1)
print("live positions:", len(live))
for r in live:
    print(r["id"], r["owner"], r["token0"][:10], r["token1"][:10], r["liquidity"], r["owed0"], r["owed1"])
