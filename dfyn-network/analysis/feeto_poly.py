#!/usr/bin/env python3
"""Polygon-only feeTo LP scan with incremental save."""
import json, urllib.request, time, os

UA = {"User-Agent": "Mozilla/5.0 dfyn-research", "Content-Type": "application/json"}
urls = ["https://polygon-bor-rpc.publicnode.com", "https://polygon.drpc.org"]

def rpc_batch(calls, tries=10):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode(); last = None
    for t in range(tries):
        url = urls[t % len(urls)]
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=90) as r: d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None]*len(calls)
                for it in d:
                    if isinstance(it.get("id"), int) and 0 <= it["id"] < len(calls):
                        out[it["id"]] = it.get("result") or it.get("error")
                return out
        except Exception as e:
            last = str(e)[:100]; time.sleep(2*(t+1))
    raise RuntimeError(last)

def pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_addr(h): return "0x"+h[-40:] if isinstance(h, str) and len(h) >= 42 else None
def dec_int(h):
    try: return int(h, 16)
    except: return None

FAC = "0xe7fb3e833efe5f9c441105eb65ef8b261266423b"
FEE_TO = "0x74665b21461f8d9b23bab7d599bfd7566a95fd70"
path = "/home/heisenberg/CA/dfyn-network/analysis/feeto-poly.json"
res = {}
if os.path.exists(path):
    res = json.load(open(path))
n = dec_int(rpc_batch([("eth_call", [{"to": FAC, "data": "0x574f2ba3"}, "latest"])])[0])
pairs = []
for i in range(0, n, 50):
    idxs = list(range(i, min(i+50, n)))
    r = rpc_batch([("eth_call", [{"to": FAC, "data": "0x1e3dd18b" + hex(j)[2:].rjust(64, "0")}, "latest"]) for j in idxs])
    pairs += [dec_addr(x) for x in r]
pairs = [p for p in pairs if p]
todo = [p for p in pairs if p not in res]
print("todo", len(todo), flush=True)
for i in range(0, len(todo), 50):
    chunk = todo[i:i+50]
    r = rpc_batch([("eth_call", [{"to": p, "data": "0x70a08231" + pad(FEE_TO)}, "latest"]) for p in chunk])
    for p, x in zip(chunk, r):
        res[p] = dec_int(x) if isinstance(x, str) else None
    json.dump(res, open(path, "w"))
    print(f"{i+len(chunk)}/{len(todo)}", flush=True)
print("done. nonzero:", sum(1 for b in res.values() if b))
