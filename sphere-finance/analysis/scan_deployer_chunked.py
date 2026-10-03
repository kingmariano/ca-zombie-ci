#!/usr/bin/env python3
"""Chunked txlist scan to bypass the 10k API cap; extract contract creations."""
import sys, json, time
sys.path.insert(0, '/home/heisenberg/CA/sphere-finance/analysis')
from es import txlist

addr = sys.argv[1]
out = sys.argv[2]
ranges = [(25000000, 30000000), (30000000, 35000000), (35000000, 40000000),
          (40000000, 45000000), (45000000, 50000000), (50000000, 55000000),
          (55000000, 60000000), (60000000, 65000000), (65000000, 70000000),
          (70000000, 75000000), (75000000, 100000000)]
all_txs = {}
for lo, hi in ranges:
    for page in range(1, 60):
        d = txlist(addr, startblock=lo, endblock=hi, page=page, offset=200, sort="asc")
        if d.get("status") != "1":
            if "No transactions found" in str(d.get("result")):
                print(f"[{lo}-{hi}] empty", flush=True)
            else:
                print(f"[{lo}-{hi}] page {page} err {str(d.get('result'))[:80]}", flush=True)
            break
        res = d["result"]
        for t in res:
            all_txs[t["hash"]] = t
        if len(res) < 200:
            print(f"[{lo}-{hi}] done, {len(res)} on last page", flush=True)
            break
        time.sleep(0.12)
    time.sleep(0.2)
txs = list(all_txs.values())
json.dump(txs, open(out, "w"))
creates = [t for t in txs if t.get("to", "") == ""]
print("TOTAL unique txs:", len(txs), "creations:", len(creates), flush=True)
for t in sorted(creates, key=lambda x: int(x["blockNumber"])):
    print(t["blockNumber"], t.get("contractAddress"), t["hash"][:20], flush=True)
