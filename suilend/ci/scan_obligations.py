#!/usr/bin/env python3
"""Sample the main market's obligations table and record stored health (read-only).
Outputs ci-out/obligation_sample.json with candidates that are stored-liquidatable."""
import json, sys, os, time, urllib.request

ENDPOINTS = ["https://sui.publicnode.com", "https://mainnet.sui.rpcpool.com", "https://sui-rpc.publicnode.com"]
OUT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)
TABLE = "0xcffebc0eb9d701d7843346dab87a043a60e28e595278db5764b87a4b3919a00a"
N_TARGET = int(os.environ.get("SCAN_N", "2000"))

_rot = [0]

def rpc(method, params):
    last = None
    for attempt in range(6):
        _rot[0] += 1
        order = ENDPOINTS[_rot[0] % len(ENDPOINTS):] + ENDPOINTS[:_rot[0] % len(ENDPOINTS)]
        for ep in order:
            try:
                req = urllib.request.Request(ep, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    j = json.loads(r.read())
                if "error" in j:
                    last = j
                    continue
                time.sleep(0.25)
                return j.get("result")
            except Exception as e:
                last = str(e)
        time.sleep(8 + attempt * 10)
    raise RuntimeError(f"{method} failed: {last}")

def dv(x):
    try:
        return int(x["fields"]["value"]) / 1e18
    except Exception:
        return None

print(f"scanning up to {N_TARGET} obligations from table {TABLE[:16]}…", flush=True)
ids = []
cursor = None
while len(ids) < N_TARGET:
    r = rpc("suix_getDynamicFields", [TABLE, cursor, 50])
    ids += [e["objectId"] for e in r["data"]]
    if not r.get("hasNextPage"):
        break
    cursor = r.get("nextCursor")
ids = ids[:N_TARGET]
print("got", len(ids), "obligation ids", flush=True)

rows = []
for i in range(0, len(ids), 50):
    chunk = ids[i:i+50]
    objs = rpc("sui_multiGetObjects", [chunk, {"showContent": True}])
    for o in objs:
        if not (isinstance(o, dict) and o.get("data", {}).get("content")):
            continue
        f = o["data"]["content"]["fields"]
        w = dv(f.get("weighted_borrowed_value_usd", {}))
        u = dv(f.get("unhealthy_borrow_value_usd", {}))
        d = dv(f.get("deposited_value_usd", {}))
        ub = dv(f.get("unweighted_borrowed_value_usd", {}))
        rows.append({
            "id": o["data"]["objectId"],
            "weighted": w, "unhealthy": u, "deposited": d, "unweighted_borrowed": ub,
            "super_unhealthy": dv(f.get("super_unhealthy_borrow_value_usd", {})),
            "n_deposits": len(f.get("deposits", [])), "n_borrows": len(f.get("borrows", [])),
            "borrow_coins": [b["fields"]["coin_type"]["fields"]["name"].split("::")[-1] for b in f.get("borrows", [])],
            "deposit_coins": [b["fields"]["coin_type"]["fields"]["name"].split("::")[-1] for b in f.get("deposits", [])],
        })
    if i % 500 == 0:
        print(f"  fetched {i+len(chunk)}", flush=True)

active = [r for r in rows if r["n_borrows"] > 0]
liquidatable = [r for r in rows if r["weighted"] and r["unhealthy"] and r["weighted"] > r["unhealthy"]]
total_borrowed = sum((r["unweighted_borrowed"] or 0) for r in rows)
total_deposited = sum((r["deposited"] or 0) for r in rows)
summary = {"scanned": len(rows), "active": len(active), "stored_liquidatable": len(liquidatable),
           "sum_unweighted_borrowed_usd": round(total_borrowed, 2), "sum_deposited_usd": round(total_deposited, 2)}
json.dump({"summary": summary, "candidates": liquidatable[:50], "sample": rows[:100]},
          open(os.path.join(OUT, "obligation_sample.json"), "w"), indent=1)
print(json.dumps(summary), flush=True)
for c in liquidatable[:10]:
    print(" CAND", c["id"], "w=", round(c["weighted"], 2), "unhl=", round(c["unhealthy"], 2),
          "dep=", round(c["deposited"], 2), "borrow=", c["borrow_coins"], "dep=", c["deposit_coins"], flush=True)
print("DONE")
