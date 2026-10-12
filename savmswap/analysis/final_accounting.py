#!/usr/bin/env python3
"""Final accounting: classify each pool's value by LP custody; compute category sums."""
import json
from prom import *

PRICE_WPROM = 5.254945355604462  # DefiLlama/coingecko PROM at ts 1791798779
PRICE_USDT = 1.0
BURN1 = "0x000000000000000000000000000000000000dead"
BURN2 = "0x0000000000000000000000000000000000000000"

pt = json.load(open("pair_table.json"))
lh = json.load(open("lp_holders.json"))
blk = hex(block_number())

W = "0x04a21a38d5e275d6023b27504beb3095dc43b0c0"
U = "0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed"
MAIN = "0x1ddbf7113e3711ae9918f2dc14efb6b302b1e0d2"
FEETO = "0x55594e57f80b2decd63608a4f2802f8003633ad2"

cats = {}
tot = {"wprom": 0.0, "usdt": 0.0, "usd": 0.0}
fee_lp_usd = 0.0
rows_out = []
for r in pt["rows"]:
    p = r["pair"]
    a0, a1 = r["A0"], r["A1"]
    w = a0 if r["t0"] == W else (a1 if r["t1"] == W else 0.0)
    u = a0 if r["t0"] == U else (a1 if r["t1"] == U else 0.0)
    usd = w * PRICE_WPROM + u * PRICE_USDT
    tot["wprom"] += w; tot["usdt"] += u; tot["usd"] += usd
    # feeTo minted LP value
    if r["lp"] > 0 and usd > 0:
        fee_lp_usd += (r["feeTo_lp"] / r["lp"]) * usd
    info = lh.get(p, {})
    holders = info.get("holders", [])
    top = holders[0] if holders else None
    if p == MAIN:
        cat = "main-live"
    elif top and top["addr"].lower() in (BURN1, BURN2) and top["value"] / r["lp"] > 0.9:
        cat = "burned-LP (locked, swap-only)"
    elif top and top["is_contract"]:
        cat = "contract-held LP"
    elif top:
        cat = "EOA-held LP (token owner/other)"
    else:
        cat = "no-LP-info"
    c = cats.setdefault(cat, {"count": 0, "wprom": 0.0, "usdt": 0.0, "usd": 0.0, "pools": []})
    c["count"] += 1; c["wprom"] += w; c["usdt"] += u; c["usd"] += usd
    if usd > 10:
        c["pools"].append({"pair": p, "sym": f"{r['sym0']}/{r['sym1']}", "usd": round(usd, 2), "wprom": round(w, 3)})
    rows_out.append({"pair": p, "sym0": r["sym0"], "sym1": r["sym1"], "wprom": w, "usdt": u, "usd": usd, "category": cat,
                     "top_holder": top["addr"] if top else None, "top_share": (top["value"] / r["lp"]) if top and r["lp"] else None})

print("block", int(blk, 16), "| WPROM price $%.4f | total wprom %.3f | total usdt %.3f | total usd %.2f" % (PRICE_WPROM, tot["wprom"], tot["usdt"], tot["usd"]))
print("feeTo minted LP value across all pairs: $%.2f" % fee_lp_usd)
for cat, c in sorted(cats.items(), key=lambda kv: -kv[1]["usd"]):
    print(f"\n== {cat}: {c['count']} pools, {c['wprom']:.3f} WPROM, {c['usdt']:.3f} USDT, ${c['usd']:.2f}")
    for x in sorted(c["pools"], key=lambda z: -z["usd"])[:25]:
        print("   ", x)
json.dump({"block": int(blk, 16), "price_wprom": PRICE_WPROM, "totals": tot, "cats": cats, "fee_lp_usd": fee_lp_usd, "rows": rows_out},
          open("final_accounting.json", "w"), indent=1)
