#!/usr/bin/env python3
"""Aggregate BaseSwap V2 scan output into the analysis used in README.

Reads ci-out/{pairs.json,tokens.json,scan_summary.json,masterchef.json} and writes:
  analysis/agg_summary.json
  analysis/top20.txt
  analysis/arb_deviations.txt
No network access (pure post-processing of already-collected evidence).
"""
import json, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
CIOUT = os.path.join(ROOT, "ci-out")
if "--ciout" in sys.argv:
    CIOUT = sys.argv[sys.argv.index("--ciout") + 1]

pairs = json.load(open(os.path.join(CIOUT, "pairs.json")))
toks = json.load(open(os.path.join(CIOUT, "tokens.json")))
summary = json.load(open(os.path.join(CIOUT, "scan_summary.json")))

meta = toks["tokens"]; prices = toks["prices"]

def price(t):
    return prices.get((t or "").lower())

def dec(t):
    d = meta.get((t or "").lower(), {}).get("decimals")
    return 18 if d is None else d

def sym(t):
    return meta.get((t or "").lower(), {}).get("symbol") or (t or "")[:10]

# top pairs
top = sorted(pairs, key=lambda x: -x["tvl_usd"])[:25]
lines = []
for i, p in enumerate(top):
    lines.append(f"{i:2d} {p['pair']} {sym(p['token0']):>10}/{sym(p['token1']):<10} "
                 f"TVL ${p['tvl_usd']:>12,.2f} excess ${p['excess_usd']:>10,.2f} "
                 f"priced_both={p['priced_both']} sup={p['totalSupply']}")
open(os.path.join(BASE, "top25.txt"), "w").write("\n".join(lines) + "\n")

# excess ranking (all)
excess = [p for p in pairs if p["excess_usd"] > 0.01]
excess.sort(key=lambda x: -x["excess_usd"])

# price deviation (both DefiLlama-priced, decent depth)
devs = []
for p in pairs:
    if not p["priced_both"] or p["tvl_usd"] < 200:
        continue
    t0, t1 = p["token0"], p["token1"]
    p0, p1 = price(t0), price(t1)
    if not p0 or not p1 or not p["reserve0"] or not p["reserve1"]:
        continue
    h0 = p["reserve0"] / 10 ** dec(t0)
    h1 = p["reserve1"] / 10 ** dec(t1)
    implied0 = h1 * p1 / h0 if h0 else 0
    implied1 = h0 * p0 / h1 if h1 else 0
    d0 = (implied0 / p0 - 1) * 100 if p0 else 0
    d1 = (implied1 / p1 - 1) * 100 if p1 else 0
    devs.append({"pair": p["pair"], "s0": sym(t0), "s1": sym(t1), "tvl": p["tvl_usd"],
                 "dev0_pct": round(d0, 2), "dev1_pct": round(d1, 2),
                 "res0": h0, "res1": h1})
devs.sort(key=lambda x: -max(abs(x["dev0_pct"]), abs(x["dev1_pct"])))
open(os.path.join(BASE, "arb_deviations.txt"), "w").write(
    "\n".join(f"{d['pair']} {d['s0']}/{d['s1']} TVL ${d['tvl']:,.0f} dev0 {d['dev0_pct']:+.2f}% dev1 {d['dev1_pct']:+.2f}%" for d in devs[:60]) + "\n")

agg = {
    "scan": summary,
    "top_pair_tvl_sum_25": round(sum(p["tvl_usd"] for p in top), 2),
    "tvl_all": round(sum(p["tvl_usd"] for p in pairs), 2),
    "skim_excess_total_usd": round(sum(p["excess_usd"] for p in excess), 2),
    "skim_excess_pairs": [{"pair": p["pair"], "s0": sym(p["token0"]), "s1": sym(p["token1"]),
                            "excess_usd": p["excess_usd"], "excess0": p["excess0"], "excess1": p["excess1"]}
                           for p in excess[:20]],
    "two_sided_excess_pairs": [p["pair"] for p in pairs if (p["excess0"] or 0) > 0 and (p["excess1"] or 0) > 0],
    "pairs_balance_lt_reserve": [p["pair"] for p in pairs if (p["excess0"] is not None and p["excess0"] < 0) or (p["excess1"] is not None and p["excess1"] < 0)],
    "stuck_min_liquidity_pairs": [{"pair": p["pair"], "s0": sym(p["token0"]), "s1": sym(p["token1"]),
                                   "tvl_usd": p["tvl_usd"], "totalSupply": p["totalSupply"]}
                                  for p in pairs if p["totalSupply"] == 1000 and p["tvl_usd"] > 0],
    "stuck_min_liquidity_usd": round(sum(p["tvl_usd"] for p in pairs if p["totalSupply"] == 1000), 2),
    "deviation_top": devs[:15],
}
json.dump(agg, open(os.path.join(BASE, "agg_summary.json"), "w"), indent=1)
print(json.dumps({k: v for k, v in agg.items() if k not in ("scan", "skim_excess_pairs", "deviation_top", "pairs_balance_lt_reserve")}, indent=1))
print("excess pairs:", len(excess), "| balance<reserve pairs:", len(agg["pairs_balance_lt_reserve"]))
print(open(os.path.join(BASE, "top25.txt")).read())
print(open(os.path.join(BASE, "arb_deviations.txt")).read()[:2000])
