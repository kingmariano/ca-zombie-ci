#!/usr/bin/env python3
"""Cross-pool implied price analysis.
For every CW20 token, compute implied USD price in each pool where the other side is priced.
Report tokens with >=2 priced pools and their min/max implied price + depth.
Also compute, for the top pools, the 'arb-extractable' INJ if the token could be acquired
at the min implied price observed anywhere."""
import json, collections

PRICES = {
    "inj": (18, 7.719961405375492),
    "peggy0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599": (8, 83278.67701171205),
    "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7": (6, 0.9990592309077597),
    "peggy0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": (18, 2526.309369639584),
    "peggy0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": (6, 0.9996446058349336),
}
d = json.load(open("pairs-live.json"))
rows = json.load(open("pools-valued.json"))

# per-token implied prices: token -> list of (pair, implied_usd, other_side, other_usd, token_amount)
bytok = collections.defaultdict(list)
for r in rows:
    for i, k in enumerate(r["kinds"]):
        if not k.startswith("CW20:"):
            continue
        j = 1 - i
        ok = r["kinds"][j]
        if ok in PRICES and r["vals"][j] and r["vals"][j] > 0 and r["amounts"][i] > 0:
            dec_ok, _ = PRICES[ok]
            tok_amt = r["amounts"][i] / 1e18 if True else 0
            # token decimals unknown here; fetch later. Use raw with decimals=18 default.
            imp = r["vals"][j] / (r["amounts"][i] / 1e18)
            bytok[k].append((r["pair"], imp, ok, r["vals"][j], r["amounts"][i], r["ts"]))

multi = {k: v for k, v in bytok.items() if len(v) >= 2}
print(f"tokens with >=2 priced pools: {len(multi)}")
for k, v in sorted(multi.items(), key=lambda kv: -max(x[3] for x in kv[1])):
    imps = [x[1] for x in v]
    lo, hi = min(imps), max(imps)
    ratio = hi / lo if lo > 0 else float("inf")
    print(f"\n{k}  pools={len(v)} implied USD min={lo:.3e} max={hi:.3e} ratio={ratio:.2f}")
    for (p, imp, ok, usd, tamt, ts) in sorted(v, key=lambda x: x[1]):
        print(f"    {imp:.6e}  other={ok[:40]:40s} other_usd=${usd:,.0f} tok_amt={tamt/1e18:,.0f} pool={p}")

json.dump({k: [{"pair": p, "implied_usd": i, "other": o, "other_usd": u, "tok_raw": t, "ts": ts} for (p, i, o, u, t, ts) in v]
           for k, v in multi.items()}, open("token-implied-prices.json", "w"), indent=1)
