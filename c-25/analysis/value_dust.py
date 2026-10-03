#!/usr/bin/env python3
"""Value the live-approval dust: upper bound on any hypothetical approval drain."""
import json, urllib.request

rows = json.load(open("/home/heisenberg/CA/c-25/analysis/approvals_current.json"))
live = [r for r in rows if r["live_allowance"] > 0 and r["owner_balance"] > 0]
print(f"pairs with allowance>0 and balance>0: {len(live)}")
tokens = sorted({r["token"] for r in live})
prices = {}
for t in tokens:
    try:
        with urllib.request.urlopen(f"https://coins.llama.fi/prices/current/ethereum:{t}", timeout=20) as r:
            d = json.loads(r.read().decode())
        k = f"ethereum:{t}"
        prices[t] = d["coins"].get(k, {}).get("price", 0) or 0
    except Exception as e:
        prices[t] = 0
total = 0.0
out = []
for r in live:
    amt = r["owner_balance"] / 10 ** r["decimals"]
    px = prices.get(r["token"], 0)
    usd = amt * px
    total += usd
    out.append({**r, "amount": amt, "price_usd": px, "usd": usd})
out.sort(key=lambda x: -x["usd"])
for r in out[:20]:
    print(f"{r['symbol']:10} owner={r['owner']} amt={r['amount']:.10f} px={r['price_usd']:.4f} usd={r['usd']:.4f}")
print(f"TOTAL dust ceiling: ${total:.4f}")
json.dump({"pairs": out, "total_usd": total, "prices": prices},
          open("/home/heisenberg/CA/c-25/analysis/approval_dust_valuation.json", "w"), indent=2)
