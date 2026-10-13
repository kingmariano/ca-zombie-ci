#!/usr/bin/env python3
"""Fetch LP token holders for all SharkSwap pairs (GoldRush, local). Writes analysis/lp_holders.json.
Never prints the API key. Key read from /home/heisenberg/CA/.env at runtime."""
import json, os, re, urllib.request, time

D = os.path.dirname(os.path.abspath(__file__))
ROOT = "/home/heisenberg/CA"
st = json.load(open(os.path.join(D, "live_state.json")))

key = None
for line in open(os.path.join(ROOT, ".env")):
    m = re.match(r'\s*GOLD_RUSH_API_KEY\s*=\s*(.+)\s*$', line)
    if m:
        key = m.group(1).strip().strip('"').strip("'")
assert key, "no goldrush key"

def gr(path):
    url = "https://api.covalenthq.com/v1/" + path
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + key,
                                               "User-Agent": "research"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode())

out = {"block": st["block"], "holders": {}}
for idx, (pad, p) in enumerate(st["pairs"].items()):
    lp = p["pair"]
    try:
        holders = []
        page = 0
        while True:
            d = gr(f"8453/tokens/{lp}/token_holders_v2/?page-number={page}")
            items = d.get("data", {}).get("items", []) or []
            for it in items:
                holders.append({"address": it["address"], "balance": it["balance"]})
            if len(items) < 100:
                break
            page += 1
            if page > 5:
                break
        out["holders"][lp] = {"symbol0": p["symbol0"], "symbol1": p["symbol1"],
                              "lp_totalSupply": p["lp_totalSupply"], "holders": holders}
        top = holders[0] if holders else None
        print(f"{idx:2d} {lp} {p['symbol0']}/{p['symbol1']:<9} holders={len(holders)} "
              f"top={top['address'] if top else '-'} bal={top['balance'] if top else '-'}")
    except Exception as e:
        out["holders"][lp] = {"error": str(e)[:150]}
        print(idx, lp, "ERR", str(e)[:120])
    time.sleep(0.25)

json.dump(out, open(os.path.join(D, "lp_holders.json"), "w"), indent=1)
print("wrote lp_holders.json")
