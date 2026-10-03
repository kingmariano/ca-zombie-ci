#!/usr/bin/env python3
"""Fetch holders for all Ironclad aTokens and variable debt tokens from Mode explorer (read-only)."""
import json, time, requests

BASE = "https://explorer.mode.network/api/v2"
state = json.load(open("/home/heisenberg/CA/ironclad-finance/analysis/state_dump.json"))

def get(url, params=None):
    for attempt in range(5):
        try:
            r = requests.get(url, params=params, timeout=30)
            if r.status_code == 200:
                return r.json()
            if r.status_code == 404:
                return {"items": []}
        except Exception:
            pass
        time.sleep(1 + attempt)
    return {"items": []}

out = {}
for asset, e in state["reserves"].items():
    sym = e["symbol"]
    for kind, addr in (("aToken", e["aToken"]), ("vDebt", e["variableDebt"])):
        if not addr:
            continue
        items = []
        params = None
        pages = 0
        while pages < 8:
            d = get(f"{BASE}/tokens/{addr}/holders", params)
            its = d.get("items", [])
            items.extend(its)
            params = d.get("next_page_params")
            pages += 1
            if not params:
                break
            time.sleep(0.4)
        out[f"{sym}:{kind}"] = {
            "token": addr,
            "holders": [{"address": it["address"]["hash"], "value": it["value"]} for it in items],
        }
        print(f"{sym:10} {kind:6} holders={len(items)}", flush=True)
        time.sleep(0.3)

json.dump(out, open("/home/heisenberg/CA/ironclad-finance/analysis/holders.json", "w"), indent=1)
print("saved holders.json")
