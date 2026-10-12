#!/usr/bin/env python3
"""Check balances of all contracts deployed by Cap deployer EOAs (background-safe)."""
import json, os, urllib.request, time

key = os.environ["GOLD_RUSH_API_KEY"]
d = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state", "deployer-creations.json")))
addrs = set()
for k, v in d.items():
    for c in v:
        if c.get("contract"):
            addrs.add(c["contract"])
c2 = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state", "create2-deployments.json")))
for c in c2:
    addrs.add(c["addr"])
print("checking", len(addrs), "contracts", flush=True)
out = []
for a in sorted(addrs):
    url = f"https://api.covalenthq.com/v1/42161/address/{a}/balances_v2/?key={key}&nft=false&no-spam=true"
    try:
        r = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=45))
        items = (r.get("data") or {}).get("items") or []
        nz = [{"sym": it["contract_ticker_symbol"], "addr": it["contract_address"], "usd": it.get("quote")}
              for it in items if float(it.get("balance", 0)) > 0 and (it.get("quote") or 0) > 0.5]
        out.append({"addr": a, "nonzero": nz})
        if nz:
            print(f"  {a}: {nz}", flush=True)
    except Exception as e:
        print(a, "ERR", str(e)[:60], flush=True)
    time.sleep(0.15)
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state", "deployer-contract-balances.json"), "w"), indent=1)
print("done", flush=True)
