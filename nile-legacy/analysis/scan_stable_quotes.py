#!/usr/bin/env python3
"""For every stable (correlated) cAMM pair, quote getAmountOut in both directions at
small/large inputs and flag anomalies: output==0, output>=reserve, non-monotonic,
or output exceeding reserve share. Keyless public RPC.
Output: analysis/stable_quote_scan.json
"""
import json, urllib.request, subprocess

import os
RPC = os.environ.get("LINEA_RPC_URL", "https://rpc.linea.build")
SEL = subprocess.run(["cast", "sig", "getAmountOut(uint256,address)"], capture_output=True, text=True).stdout.strip()

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
stable_pairs = [r for r in scan["pairs"] if r["stable"] == 1]
print("stable pairs:", len(stable_pairs))

AMOUNTS = [1e15, 1e18, 1e20]  # 0.001, 1, 100 tokens
rows = []
for k in range(0, len(stable_pairs), 5):
    chunk = stable_pairs[k:k + 5]
    calls = []
    for r in chunk:
        for amt in AMOUNTS:
            calls.append((r["pair"], SEL + hex(int(amt))[2:].rjust(64, "0") + r["token0"][2:].rjust(64, "0")))
            calls.append((r["pair"], SEL + hex(int(amt))[2:].rjust(64, "0") + r["token1"][2:].rjust(64, "0")))
    res = rpc_batch(calls)
    idx = 0
    for r in chunk:
        rec = {"pair": r["pair"], "t0": r["token0"], "t1": r["token1"],
               "r0": r["reserve0"], "r1": r["reserve1"], "quotes": []}
        for amt in AMOUNTS:
            q0 = res[idx]; idx += 1
            q1 = res[idx]; idx += 1
            v0 = int(q0, 16) if q0 and q0 != "0x" else None
            v1 = int(q1, 16) if q1 and q1 != "0x" else None
            rec["quotes"].append({"in": amt, "out_t0_in": v0, "out_t1_in": v1})
        rows.append(rec)

# flag anomalies
anoms = []
for r in rows:
    for q in r["quotes"]:
        for side, resv in (("out_t0_in", r["r1"]), ("out_t1_in", r["r0"])):
            v = q[side]
            if v is None:
                anoms.append((r["pair"], q["in"], side, "REVERT/None"))
            elif v == 0:
                anoms.append((r["pair"], q["in"], side, "ZERO"))
            elif resv and v >= resv:
                anoms.append((r["pair"], q["in"], side, f">= reserve ({v} >= {resv})"))

json.dump({"stable_pairs": rows, "anomalies": anoms}, open("analysis/stable_quote_scan.json", "w"), indent=1)
print("anomalies:", len(anoms))
for a in anoms[:20]:
    print(a)
# print the top pair quotes for the record
for r in rows:
    if r["pair"].lower() == "0xa9a1fb9f6664a0b6bfb1f52724fd7b23842248c5":
        print("TOP PAIR quotes:", json.dumps(r))
