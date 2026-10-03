#!/usr/bin/env python3
"""Fetch contract names + source for a list of addresses; save to sources/."""
import sys, json, os, time
sys.path.insert(0, '/home/heisenberg/CA/sphere-finance/analysis')
from es import call

OUT = "/home/heisenberg/CA/sphere-finance/analysis/sources"
os.makedirs(OUT, exist_ok=True)

addrs = sys.argv[1:]
results = {}
for a in addrs:
    a = a.lower()
    try:
        d = call({"module": "contract", "action": "getsourcecode", "address": a})
        if d.get("status") == "1" and d.get("result"):
            r = d["result"][0]
            results[a] = {
                "name": r.get("ContractName"),
                "compiler": r.get("CompilerVersion"),
                "proxy": r.get("Proxy"),
                "impl": r.get("Implementation"),
                "verified": bool(r.get("SourceCode")),
            }
            if r.get("SourceCode"):
                json.dump(r, open(f"{OUT}/{a}.json", "w"))
            print(a, r.get("ContractName"), r.get("CompilerVersion"), "proxy=" + str(r.get("Proxy")), "impl=" + str(r.get("Implementation")), flush=True)
        else:
            results[a] = {"error": str(d.get("result"))[:80]}
            print(a, "ERR", str(d.get("result"))[:80], flush=True)
    except Exception as e:
        print(a, "EXC", str(e)[:80], flush=True)
    time.sleep(0.22)
json.dump(results, open(f"{OUT}/_names.json", "w"), indent=1)
print("DONE", len(results))
