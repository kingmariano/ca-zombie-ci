#!/usr/bin/env python3
"""Compare Dojoswap pool implied prices vs Injective orderbook mid prices for
tokens that have CW20-backed factory denoms + active spot markets."""
import json, urllib.request, urllib.parse, base64

LCD = "https://injective-api.polkachu.com"

def get(path, timeout=30):
    req = urllib.request.Request(LCD + path, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

# 1. all spot markets
markets, key = [], None
for _ in range(30):
    p = "/injective/exchange/v1beta1/spot/markets?pagination.limit=200"
    if key:
        p += "&pagination.key=" + urllib.parse.quote(key)
    d = get(p)
    markets.extend(d.get("markets", []))
    key = (d.get("pagination") or {}).get("next_key")
    if not key:
        break
print("total spot markets:", len(markets))
active = [m for m in markets if m.get("status") == "Active"]
print("active:", len(active))

# 2. markets whose base is a CW20-backed factory denom
cw20m = [m for m in active if m["base_denom"].startswith("factory/") and "/inj1" in m["base_denom"]]
print("active CW20-backed markets:", len(cw20m))

rows = json.load(open("pools-valued.json"))
pairs = {p["contract_addr"]: p for p in json.load(open("pairs-live.json"))["pairs"]}

def denom_of_cw20(c):
    # find market whose base_denom ends with the cw20 address
    out = []
    for m in cw20m:
        sub = m["base_denom"].split("/")[-1]
        if sub == c:
            out.append(m)
    return out

report = []
for r in rows:
    if r["usd_known"] < 100:
        continue
    for i, k in enumerate(r["kinds"]):
        if not k.startswith("CW20:"):
            continue
        c = k.split(":", 1)[1]
        ms = denom_of_cw20(c)
        if not ms:
            continue
        for m in ms:
            mid = m["market_id"]
            try:
                ob = get(f"/injective/exchange/v1beta1/spot/orderbook/{mid}?limit=5")
            except Exception as e:
                ob = {}
            bids = ob.get("buys_price_level", [])
            asks = ob.get("sells_price_level", [])
            bid = float(bids[0]["p"]) if bids else None
            ask = float(asks[0]["p"]) if asks else None
            quote = m["quote_denom"]
            # pool implied price in quote units (assume quote == priced side units)
            j = 1 - i
            if r["kinds"][j] == quote:
                imp = (r["amounts"][j] / 10**18) / (r["amounts"][i] / 10**18)  # raw ratio if quote has 18 dec
            else:
                imp = None
            report.append({"pair": r["pair"], "cw20": c, "market": mid, "ticker": m["ticker"],
                           "quote": quote, "bid": bid, "ask": ask,
                           "pool_implied_raw": imp, "pool_usd": r["usd_known"]})
            print(f"{m['ticker']:24s} bid={bid} ask={ask}  pool={r['pair'][:44]} implied_raw={imp}")

json.dump(report, open("orderbook-vs-pool.json", "w"), indent=1)
