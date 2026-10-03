#!/usr/bin/env python3
"""Complete current token balances for the 34 enabled Safes + module via Blockscout API v2."""
import json, os, time, urllib.request, urllib.parse

ANALYSIS = "/home/heisenberg/CA/c-26/analysis"
OUT = os.path.join(ANALYSIS, "balances")
os.makedirs(OUT, exist_ok=True)
state = json.load(open(os.path.join(ANALYSIS, "events_state.json")))
addrs = state["currently_enabled_by_events"] + ["0x1f1d37a3bf840e35c6a860c7c2da71fe555123ca"]

all_out = {}
for i, a in enumerate(addrs):
    rows = []
    params = {}
    for page in range(6):
        url = f"https://eth.blockscout.com/api/v2/addresses/{a}/token-balances"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    d = json.loads(r.read().decode())
                break
            except Exception as e:
                print("retry", a, e, flush=True)
                time.sleep(2 + attempt)
        else:
            d = None
        if not isinstance(d, list) or not d:
            break
        rows += d
        # pagination: blockscout returns next_page_params on some endpoints; token-balances is not paginated via next_page_params
        break
    keep = []
    for it in rows:
        v = int(it.get("value") or 0)
        if v <= 0:
            continue
        t = it.get("token") or {}
        keep.append({
            "address": (t.get("address_hash") or "").lower(),
            "symbol": t.get("symbol"),
            "name": t.get("name"),
            "decimals": t.get("decimals"),
            "type": t.get("type"),
            "value": str(v),
            "exchange_rate": t.get("exchange_rate"),
        })
    all_out[a.lower()] = keep
    print(f"[{i+1}/{len(addrs)}] {a} tokens={len(keep)}", flush=True)
    json.dump(all_out, open(os.path.join(OUT, "blockscout_balances.json"), "w"), indent=1)
    time.sleep(0.4)
print("done", len(all_out))
