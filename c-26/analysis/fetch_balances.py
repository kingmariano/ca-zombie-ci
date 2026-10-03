#!/usr/bin/env python3
"""GoldRush balances_v2 for all currently-enabled Safes + module. Read-only."""
import json, os, time, urllib.request, urllib.parse

ANALYSIS = "/home/heisenberg/CA/c-26/analysis"
KEY = os.environ["GOLD_RUSH_API_KEY"]
state = json.load(open(os.path.join(ANALYSIS, "events_state.json")))
addrs = state["currently_enabled_by_events"]
MODULE = "0x1f1d37a3bf840e35c6a860c7c2da71fe555123ca"
if MODULE not in [a.lower() for a in addrs]:
    addrs = addrs + [MODULE]

out = {}
os.makedirs(os.path.join(ANALYSIS, "balances"), exist_ok=True)
for i, a in enumerate(addrs):
    url = (f"https://api.covalenthq.com/v1/1/address/{a}/balances_v2/"
           f"?key={KEY}&nft=false&no-spam=true")
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=25) as r:
                d = json.loads(r.read().decode())
            break
        except Exception as e:
            print("retry", a, e, flush=True)
            time.sleep(3 + 2 * attempt)
    else:
        d = {"error": True}
    items = (d.get("data") or {}).get("items") or []
    keep = []
    for it in items:
        bal = int(it.get("balance") or 0)
        if bal > 0:
            keep.append({
                "symbol": it.get("contract_ticker_symbol"),
                "address": (it.get("contract_address") or "").lower(),
                "decimals": it.get("contract_decimals"),
                "balance": str(bal),
                "is_native": (it.get("contract_address") or "").lower() == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                "name": it.get("contract_name"),
            })
    out[a.lower()] = keep
    json.dump(out, open(os.path.join(ANALYSIS, "balances", "all_balances.json"), "w"), indent=1)
    tot = sum(1 for k in keep)
    print(f"[{i+1}/{len(addrs)}] {a} nonzero_items={tot}", flush=True)
    time.sleep(1.4)

json.dump(out, open(os.path.join(ANALYSIS, "balances", "all_balances.json"), "w"), indent=1)
print("saved", len(out), "addresses")
