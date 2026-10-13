#!/usr/bin/env python3
"""Price SharkSwap pairs using DefiLlama coins API (public). Output analysis/prices.json"""
import json, os, urllib.request

D = os.path.join(os.path.dirname(os.path.abspath(__file__)))
st = json.load(open(os.path.join(D, "live_state.json")))

tokens = {}
for p in st["pairs"].values():
    for k in ("0", "1"):
        a = p["token" + k]
        tokens[a] = {"symbol": p["symbol" + k], "decimals": p["dec" + k]}

# DefiLlama current prices
addrs = sorted(tokens)
prices = {}
for i in range(0, len(addrs), 40):
    chunk = addrs[i:i + 40]
    keys = ",".join("base:" + a.lower() for a in chunk)
    url = "https://coins.llama.fi/prices/current/" + keys
    req = urllib.request.Request(url, headers={"User-Agent": "research"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.loads(r.read().decode())
    for k, v in d.get("coins", {}).items():
        prices[k.split(":")[1].lower()] = v

out = {"prices": {}, "pairs": []}
for p in st["pairs"].values():
    def usd(k):
        a = p["token" + k]
        dec = p["dec" + k] or 18
        px = prices.get(a.lower(), {}).get("price")
        return None if px is None else p["reserve" + k] / 10 ** dec * px
    u0, u1 = usd("0"), usd("1")
    tot = (u0 or 0) + (u1 or 0)
    out["pairs"].append({
        "pair": p["pair"], "symbol0": p["symbol0"], "symbol1": p["symbol1"],
        "token0": p["token0"], "token1": p["token1"],
        "reserve0": p["reserve0"], "reserve1": p["reserve1"],
        "usd0": u0, "usd1": u1, "usd_total": tot,
        "lp_totalSupply": p["lp_totalSupply"],
    })
out["prices"] = {a: {"symbol": tokens[a]["symbol"], "price": prices.get(a.lower(), {}).get("price")} for a in addrs}
out["pairs"].sort(key=lambda x: -x["usd_total"])
tot = sum(x["usd_total"] for x in out["pairs"])
print(f"TOTAL all 52 pairs: ${tot:,.2f}")
for x in out["pairs"][:25]:
    print(f"{x['usd_total']:>12,.2f}  {x['symbol0']:>10}/{x['symbol1']:<10} {x['pair']}  (u0={x['usd0'] if x['usd0'] is None else round(x['usd0'],2)}, u1={x['usd1'] if x['usd1'] is None else round(x['usd1'],2)})")
unpriced = [a for a in addrs if prices.get(a.lower(), {}).get("price") is None]
print("unpriced tokens:", len(unpriced))
for a in unpriced:
    print("  ", tokens[a]["symbol"], a)
json.dump(out, open(os.path.join(D, "prices.json"), "w"), indent=1)
