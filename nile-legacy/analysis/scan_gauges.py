#!/usr/bin/env python3
"""For each cAMM pair: find its gauge via voter.gauges(pair), read gauge staked LP balance
and gauge NILE balance, isAlive. Keyless public RPC.
Output: analysis/gauge_scan.json
"""
import json, urllib.request

import os
RPC = os.environ.get("LINEA_RPC_URL", "https://rpc.linea.build")
VOTER = "0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869"
NILE = "0xAAAac83751090C6ea42379626435f805DDF54DC8"

def rpc_batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": c[0], "data": c[1]}, "latest"]} for i, c in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        res = json.load(r)
    out = {}
    for item in res:
        out[item["id"]] = item.get("result")
    return [out.get(i) for i in range(len(calls))]

scan = json.load(open("analysis/pair_scan.json"))
pairs = [r["pair"] for r in scan["pairs"]]

# voter.gauges(address) selector
GAUGES = "0x" + __import__("subprocess").run(["cast", "sig", "gauges(address)"], capture_output=True, text=True).stdout.strip()[2:]
ISALIVE = "0x" + __import__("subprocess").run(["cast", "sig", "isAlive(address)"], capture_output=True, text=True).stdout.strip()[2:]
BAL = "0x70a08231"

res_gauges = []
for k in range(0, len(pairs), 10):
    chunk = pairs[k:k + 10]
    res = rpc_batch([(VOTER, GAUGES + p[2:].rjust(64, "0")) for p in chunk])
    res_gauges += [(p, ("0x" + r[-40:]) if r and r != "0x" else None) for p, r in zip(chunk, res)]

rows = []
for k in range(0, len(res_gauges), 10):
    chunk = res_gauges[k:k + 10]
    calls = []
    for p, g in chunk:
        if g and int(g, 16) != 0:
            calls.append((p, BAL + g[2:].rjust(64, "0")))  # LP token balance of gauge (staked)
            calls.append((NILE, BAL + g[2:].rjust(64, "0")))  # gauge NILE balance
            calls.append((VOTER, ISALIVE + g[2:].rjust(64, "0")))
        else:
            calls += [None, None, None]
    valid = [c for c in calls if c]
    res = rpc_batch(valid) if valid else []
    it = iter(res)
    for p, g in chunk:
        if g and int(g, 16) != 0:
            lp = int(next(it), 16)
            nile = int(next(it), 16)
            alive = int(next(it), 16)
            rows.append({"pair": p, "gauge": g, "staked_lp": lp, "gauge_nile": nile, "alive": alive})
        else:
            rows.append({"pair": p, "gauge": None, "staked_lp": 0, "gauge_nile": 0, "alive": 0})

json.dump(rows, open("analysis/gauge_scan.json", "w"), indent=1)
print("pairs with gauge:", sum(1 for r in rows if r["gauge"]))
print("pairs with staked LP > 0:", sum(1 for r in rows if r["staked_lp"] > 0))
print("total gauges NILE:", sum(r["gauge_nile"] for r in rows) / 1e18)
for r in sorted(rows, key=lambda r: -r["staked_lp"])[:15]:
    print(json.dumps(r))
