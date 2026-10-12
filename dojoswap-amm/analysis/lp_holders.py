#!/usr/bin/env python3
"""For the top pools by known USD, enumerate LP token holders (cw20 all_accounts)
and their balances; flag contract holders (addresses with code)."""
import json, base64, urllib.request
from concurrent.futures import ThreadPoolExecutor

LCDS = ["https://injective-api.polkachu.com", "https://injective-rest.publicnode.com"]

def get(path, timeout=30):
    last = None
    for lcd in LCDS:
        try:
            req = urllib.request.Request(lcd + path, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
    raise RuntimeError(str(last))

def cwq(contract, query):
    b64 = base64.b64encode(json.dumps(query, separators=(",", ":")).encode()).decode()
    return get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b64}").get("data", {})

rows = json.load(open("pools-valued.json"))
top = [r for r in rows if r["usd_known"] >= 300][:22]
print("pools:", len(top))

def holders(lp):
    accts, key = [], None
    for _ in range(40):
        q = {"all_accounts": {"limit": 100}}
        if key:
            q["all_accounts"]["start_after"] = key
        d = cwq(lp, q)
        page = d.get("accounts", [])
        accts.extend(page)
        if len(page) < 100:
            break
        key = page[-1]
    return accts

def bal(lp, acct):
    d = cwq(lp, {"balance": {"address": acct}})
    return int(d.get("balance", 0))

out = []
for r in top:
    lp = r["lp"]
    try:
        accts = holders(lp)
    except Exception as e:
        out.append({"pair": r["pair"], "lp": lp, "err": str(e), "usd": r["usd_known"]})
        continue
    with ThreadPoolExecutor(max_workers=6) as ex:
        bals = list(ex.map(lambda a: bal(lp, a), accts))
    tot = sum(bals)
    top_h = sorted(zip(accts, bals), key=lambda x: -x[1])[:8]
    out.append({"pair": r["pair"], "lp": lp, "usd": round(r["usd_known"], 2),
                "n_holders": len(accts), "lp_sum": tot, "lp_supply_pool": r["ts"],
                "top": [{"a": a, "b": b} for a, b in top_h]})
    print(f"\n== {r['pair']} (${r['usd_known']:,.0f}) lp={lp} holders={len(accts)} sum={tot}")
    for a, b in top_h:
        print(f"   {a}  {b}")

json.dump(out, open("lp-holders.json", "w"), indent=1)
