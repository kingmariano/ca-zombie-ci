#!/usr/bin/env python3
"""Farm/vault balance pass: how much stakingToken / DFYN / ROUTE each live farm holds."""
import json, urllib.request, time

UA = {"User-Agent": "Mozilla/5.0 dfyn-research", "Content-Type": "application/json"}
RPCS = ["https://polygon-bor-rpc.publicnode.com", "https://polygon.drpc.org"]
CUR = [0]

def rpc_batch(calls, timeout=90, tries=6):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for t in range(tries):
        url = RPCS[CUR[0] % len(RPCS)]
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item["result"] if "result" in item else {"error": item.get("error")}
                return out
        except Exception as e:
            last = str(e)[:100]; CUR[0] += 1; time.sleep(1.5 * (t + 1))
    raise RuntimeError(f"batch fail: {last}")

def pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_int(h):
    try: return int(h, 16)
    except: return None

DFYN = "0xc168e40227e4ebd8c1cae80f7a55a4f0e6d66c97"
ROUTE = "0x16eccfdbb4ee1a85a33f3a9b21175cd7ae753db4"

scan = json.load(open("/home/heisenberg/CA/dfyn-network/analysis/farms-scan.json"))
farms = {a: v for a, v in scan.items() if v.get("stakingToken")}
print("farms with stakingToken:", len(farms))
out = {}
addrs = list(farms.keys())
for i in range(0, len(addrs), 15):
    chunk = addrs[i:i+15]
    calls = []
    for a in chunk:
        st = farms[a]["stakingToken"]
        calls += [("eth_call", [{"to": st, "data": "0x70a08231" + pad(a)}, "latest"]),
                  ("eth_call", [{"to": DFYN, "data": "0x70a08231" + pad(a)}, "latest"]),
                  ("eth_call", [{"to": ROUTE, "data": "0x70a08231" + pad(a)}, "latest"]),
                  ("eth_call", [{"to": a, "data": "0x18160ddd"}, "latest"])]
    r = rpc_batch(calls)
    for j, a in enumerate(chunk):
        out[a] = {"stakingToken": farms[a]["stakingToken"], "staked": dec_int(r[4*j]) if isinstance(r[4*j], str) else None,
                  "dfyn": dec_int(r[4*j+1]) if isinstance(r[4*j+1], str) else None,
                  "route": dec_int(r[4*j+2]) if isinstance(r[4*j+2], str) else None,
                  "totalSupply_ts": dec_int(r[4*j+3]) if isinstance(r[4*j+3], str) else None}
    print(f"{min(i+15,len(addrs))}/{len(addrs)}", flush=True)
json.dump(out, open("/home/heisenberg/CA/dfyn-network/analysis/farms-balances.json", "w"), indent=1)
tot_dfyn = sum(v["dfyn"] or 0 for v in out.values()) / 1e18
tot_route = sum(v["route"] or 0 for v in out.values()) / 1e18
tot_staked = sum(v["staked"] or 0 for v in out.values())
nz = [(a, v) for a, v in out.items() if (v["dfyn"] or 0) > 0 or (v["staked"] or 0) > 0]
print("farms with nonzero holdings:", len(nz))
print(f"TOTAL DFYN held by farms: {tot_dfyn:,.2f}")
print(f"TOTAL ROUTE held by farms: {tot_route:,.2f}")
top = sorted(nz, key=lambda kv: -(kv[1]["dfyn"] or 0))[:15]
for a, v in top:
    print(a, "dfyn", (v["dfyn"] or 0)/1e18, "staked", v["staked"], "ts", v["totalSupply_ts"])
