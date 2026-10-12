#!/usr/bin/env python3
import sys, json, time
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
r1 = json.load(open("/home/heisenberg/CA/armada/analysis/recon1.json"))
r2 = json.load(open("/home/heisenberg/CA/armada/analysis/recon2.json"))
out = {}
for vk, v in r1["vaults"].items():
    m = v["lp_mint"]
    vals = None
    for attempt in range(5):
        try:
            r = rpc("getTokenLargestAccounts", [m], timeout=30)
            vals = r.get("value", []) if r else []
            break
        except Exception as e:
            time.sleep(2)
    out[vk] = {"lp_mint": m, "supply": r2["lp_supply"].get(m, {}).get("value", {}).get("uiAmountString"),
               "largest": vals[:6] if vals is not None else "fail"}
    print(vk[:8], "supply", out[vk]["supply"], "largest:",
          [(x.get("address", "")[:10], x.get("uiAmountString")) for x in (vals or [])[:4] if isinstance(x, dict)], flush=True)
json.dump(out, open("/home/heisenberg/CA/armada/analysis/recon6_lpholders.json", "w"), indent=1)
print("DONE")
