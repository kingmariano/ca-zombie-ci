#!/usr/bin/env python3
"""Per-pair USD valuation with DefiLlama prices (2026-10-11). Read-only analysis."""
import json, collections

PRICES = {  # (denom -> (decimals, usd))
    "inj": (18, 7.719961405375492),
    "peggy0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599": (8, 83278.67701171205),
    "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7": (6, 0.9990592309077597),
    "peggy0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": (18, 2526.309369639584),
    "peggy0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": (6, 0.9996446058349336),
    "peggy0x943Af2ece93118B973c95c2F698EE9D15002e604": (18, 3.398172212796185e-05),
    "ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9": (6, 4.35),  # ATOM approx
}

d = json.load(open("pairs-live.json"))
pairs = {p["contract_addr"]: p for p in d["pairs"]}
pools = {r["contract"]: r["pool"] for r in d["pools"] if "pool" in r}

def denom_key(info):
    if "native_token" in info:
        return info["native_token"]["denom"]
    return "CW20:" + info["token"]["contract_addr"]

rows = []
for addr, pool in pools.items():
    pinfo = pairs.get(addr)
    if not pinfo:
        continue
    a = pool["assets"]
    ts = int(pool["total_share"])
    vals, amts, kinds = [], [], []
    for x in a:
        k = denom_key(x["info"])
        amt = int(x["amount"])
        amts.append(amt); kinds.append(k)
        if k in PRICES:
            dec, usd = PRICES[k]
            vals.append(amt / 10**dec * usd)
        else:
            vals.append(None)
    total = sum(v for v in vals if v is not None)
    rows.append({"pair": addr, "lp": pinfo["liquidity_token"], "kinds": kinds,
                 "amounts": amts, "vals": vals, "ts": ts, "usd_known": total,
                 "priced_both": all(v is not None for v in vals)})

rows.sort(key=lambda r: -(r["usd_known"] or 0))
tot = sum(r["usd_known"] for r in rows)
print(f"total USD (known-price denoms only): ${tot:,.2f}")
print(f"pools with both sides priced: {sum(1 for r in rows if r['priced_both'])}")
print("\n== top 40 pools by known USD ==")
for r in rows[:40]:
    print(f"${r['usd_known']:>12,.2f}  ts={r['ts']:>22}  {r['pair']}")
    for k, amt, v in zip(r["kinds"], r["amounts"], r["vals"]):
        vs = f"${v:,.2f}" if v is not None else "UNPRICED"
        print(f"      {k:70s} {amt:>28} {vs}")

# aggregate by denom usd
byk = collections.Counter()
for r in rows:
    for k, amt, v in zip(r["kinds"], r["amounts"], r["vals"]):
        if v is not None:
            byk[k] += v
print("\n== USD by denom ==")
for k, v in byk.most_common(20):
    print(f"${v:>12,.2f}  {k}")

json.dump(rows, open("pools-valued.json", "w"), indent=1)
