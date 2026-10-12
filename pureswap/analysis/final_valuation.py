#!/usr/bin/env python3
"""Final PureSwap state/valuation split: E-U / H-O / P / S with USD.

Reads the dumps produced by fetch_state.py / fetch_maker_deep.py / chef-pools.json.
Prices: DefiLlama snapshot (llama-prices.json) for real tokens; internal pool mids
for MX and PURE (not externally liquid). All values are nominal-as-observed.
"""
import json, os

HERE = os.path.dirname(__file__)
d = json.load(open(os.path.join(HERE, "pairs-state.json")))
tok = json.load(open(os.path.join(HERE, "tokens.json")))
makers = json.load(open(os.path.join(HERE, "maker-lp-all.json")))
chef = json.load(open(os.path.join(HERE, "chef-pools.json")))
llama = json.load(open(os.path.join(HERE, "llama-prices.json")))["coins"]

px = {}
for k, v in llama.items():
    px[k.split(":", 1)[1].lower()] = v["price"]
# internal mids (nominal exit value only inside PureSwap)
MX = "0x9f882567a62a5560d147d64871776eea72df41d3"
PURE = "0x481f0557fb3bb5ee461fd47f287b1ca944ad89bc"
px[MX] = 3087.6053126904635 / 1613.0482533005058       # Pancake MX/BUSD mid
px[PURE] = 646.049141 / 6264749.149944                 # PURE/BUSD mid
INTERNAL = {MX, PURE}

chef_bytes = {p["lp"]: p["chefBal"] or 0 for p in chef}

def usd(a, dec, p):
    return a / 10 ** dec * (p or 0.0)

rows = []
tot = {"pool": 0.0, "maker": 0.0, "maker_real": 0.0, "chef": 0.0, "chef_real": 0.0,
       "other": 0.0, "other_real": 0.0, "pool_real": 0.0, "dust_excess": 0.0}
mkr = {m["pair"]: m for m in makers}
for p in d["pairs"]:
    t0, t1 = p["token0"], p["token1"]
    d0, d1 = int(tok[t0]["decimals"]), int(tok[t1]["decimals"])
    v0, v1 = usd(p["reserve0"], d0, px.get(t0)), usd(p["reserve1"], d1, px.get(t1))
    real0 = 0.0 if t0 in INTERNAL else v0
    real1 = 0.0 if t1 in INTERNAL else v1
    pool, pool_real = v0 + v1, real0 + real1
    ts = p["totalSupply"] or 0
    m = mkr.get(p["pair"], {})
    m_lp = (m.get("lp_maker1") or 0) + (m.get("lp_maker2") or 0)
    c_lp = min(chef_bytes.get(p["pair"], 0), ts)
    o_lp = max(ts - m_lp - c_lp - 1000, 0)
    if ts == 0:
        continue
    maker = pool * m_lp / ts
    maker_real = pool_real * m_lp / ts
    chefv = pool * c_lp / ts
    chef_real = pool_real * c_lp / ts
    other = pool * o_lp / ts
    other_real = pool_real * o_lp / ts
    e0 = p.get("excess0") or 0
    e1 = p.get("excess1") or 0
    dust = usd(e0, d0, px.get(t0)) + usd(e1, d1, px.get(t1))
    tot["pool"] += pool; tot["pool_real"] += pool_real
    tot["maker"] += maker; tot["maker_real"] += maker_real
    tot["chef"] += chefv; tot["chef_real"] += chef_real
    tot["other"] += other; tot["other_real"] += other_real
    tot["dust_excess"] += dust
    rows.append({"pair": p["pair"], "sym": f'{tok[t0]["symbol"]}/{tok[t1]["symbol"]}',
                 "pool_usd": round(pool, 2), "pool_real_usd": round(pool_real, 2),
                 "maker_share": round(m_lp / ts, 4), "maker_usd": round(maker, 2),
                 "maker_real_usd": round(maker_real, 2),
                 "chef_usd": round(chefv, 2), "other_usd": round(other, 2), "other_real_usd": round(other_real, 2),
                 "dust_usd": round(dust, 4)})
rows.sort(key=lambda r: -r["pool_usd"])
json.dump({"block": d["block"], "rows": rows, "totals": {k: round(v, 2) for k, v in tot.items()}},
          open(os.path.join(HERE, "valuation-split.json"), "w"), indent=2)

print(f"{'pair':46}{'pool$':>11}{'poolReal$':>11}{'maker$':>11}{'makerReal$':>12}{'chef$':>9}{'other$':>9}{'dust$':>8}")
for r in rows[:18]:
    print(f"{r['pair']} {r['sym']:>16}{r['pool_usd']:>11.0f}{r['pool_real_usd']:>11.0f}{r['maker_usd']:>11.0f}{r['maker_real_usd']:>12.0f}{r['chef_usd']:>9.0f}{r['other_usd']:>9.0f}{r['dust_usd']:>8.2f}")
t = tot
print("\nTOTALS (nominal, block %d):" % d["block"])
print(f"  pool total            ${t['pool']:,.0f}   (llama-priced only: ${t['pool_real']:,.0f})")
print(f"  maker (S, bricked)    ${t['maker']:,.0f}   (llama-priced: ${t['maker_real']:,.0f})")
print(f"  PureChef stake (H-O)  ${t['chef']:,.0f}   (llama-priced: ${t['chef_real']:,.0f})")
print(f"  other LP EOA (H-O)    ${t['other']:,.0f}   (llama-priced: ${t['other_real']:,.0f})")
print(f"  skimable excess       ${t['dust_excess']:,.4f}")
