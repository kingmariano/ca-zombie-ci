#!/usr/bin/env python3
"""Value OpenBook v1 deposits (top markets + mints) with DefiLlama prices."""
import json, urllib.request, time

A = json.load(open("/home/heisenberg/CA/serum/analysis/openbook_aggregates.json"))
top_markets = A.get("top100_markets_by_deposits", [])
top_mints = A.get("top50_mints_by_amount", [])

# collect mints
mints = set()
for m in top_markets:
    mints.add(m["coin_mint"]); mints.add(m["pc_mint"])
for m in top_mints:
    mints.add(m["mint"])
mints = [m for m in mints if m and m != "11111111111111111111111111111111"]

def llama_prices(keys):
    out = {}
    for i in range(0, len(keys), 100):
        chunk = keys[i:i+100]
        url = "https://coins.llama.fi/prices/current/" + ",".join(chunk)
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                j = json.loads(r.read().decode())
            out.update(j.get("coins", {}))
        except Exception as e:
            print("price err", str(e)[:80])
        time.sleep(0.3)
    return out

keys = [f"solana:{m}" for m in mints]
prices = llama_prices(keys)

def px(mint):
    c = prices.get(f"solana:{mint}")
    if not c: return None
    return c

# value markets
rows = []
tot = 0.0
for m in top_markets:
    c = px(m["coin_mint"]); p = px(m["pc_mint"])
    cu = 0.0; pu = 0.0
    if c and c.get("price") is not None and m.get("coin_dep"):
        cu = m["coin_dep"] * 10 ** (-c["decimals"]) * c["price"]
    if p and p.get("price") is not None and m.get("pc_dep"):
        pu = m["pc_dep"] * 10 ** (-p["decimals"]) * p["price"]
    tot += cu + pu
    rows.append({"market": m["pubkey"], "coin_mint": m["coin_mint"], "pc_mint": m["pc_mint"],
                 "coin_dep": m.get("coin_dep"), "pc_dep": m.get("pc_dep"),
                 "coin_usd": round(cu, 2), "pc_usd": round(pu, 2), "usd": round(cu + pu, 2)})
rows.sort(key=lambda r: -r["usd"])

# value top mints
mrows = []
for m in top_mints:
    c = px(m["mint"])
    usd = None
    if c and c.get("price") is not None:
        usd = m["amount"] * 10 ** (-c["decimals"]) * c["price"]
    mrows.append({"mint": m["mint"], "count": m["count"], "amount": m["amount"],
                  "usd": round(usd, 2) if usd is not None else None,
                  "symbol": (c or {}).get("symbol")})
mrows.sort(key=lambda r: -(r["usd"] or 0))

out = {
    "note": "USD valued with DefiLlama coins.llama.fi prices; deposits_total raw units; only top100 markets/top50 mints covered",
    "top100_markets_usd_sum": round(tot, 2),
    "markets_with_price": sum(1 for r in rows if r["usd"] > 0),
    "top_markets": rows[:40],
    "top_mints_usd": mrows[:40],
}
json.dump(out, open("/home/heisenberg/CA/serum/analysis/openbook_valued.json", "w"), indent=1)
print("top100 markets USD sum:", round(tot, 2))
print("top 20 markets:")
for r in rows[:20]:
    print(f"  {r['market'][:12]} coin={r['coin_usd']:>12} pc={r['pc_usd']:>12} total={r['usd']:>12}  mints {r['coin_mint'][:8]}/{r['pc_mint'][:8]}")
print("top 15 mints by USD:")
for r in mrows[:15]:
    print(f"  {r['symbol'] or '?':12s} {r['mint'][:12]} amount={r['amount']} usd={r['usd']}")
