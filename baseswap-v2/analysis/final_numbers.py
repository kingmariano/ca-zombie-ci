#!/usr/bin/env python3
"""Consolidate final BaseSwap V2 numbers from CI v2 scan + 3 gap-fill passes.

Outputs analysis/final_numbers.json and prints a summary block for the README.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AN = os.path.join(ROOT, "analysis")

v2 = json.load(open(os.path.join(AN, "ci2-backup", "pairs.json")))
v2tok = json.load(open(os.path.join(AN, "ci2-backup", "tokens.json")))
mc = json.load(open(os.path.join(AN, "ci2-backup", "masterchef.json")))
g1 = json.load(open(os.path.join(AN, "missing_scan.json")))
g2 = json.load(open(os.path.join(AN, "missing_scan2.json")))
g3 = json.load(open(os.path.join(AN, "missing_scan3.json")))
scan = json.load(open(os.path.join(AN, "ci2-backup", "scan_summary.json")))

meta = v2tok["tokens"]; prices = v2tok["prices"]

def dec(t):
    d = meta.get((t or "").lower(), {}).get("decimals")
    return d

# --- corrected TVL from v2 rows (robust implied pricing) ---
def side_usd(t, reserve):
    if not t or reserve is None:
        return 0.0, False
    p = prices.get(t.lower())
    d = dec(t)
    if p is None or d is None:
        return 0.0, False
    src = meta.get(t.lower(), {}).get("price_source")
    if src == "implied" and not (1e-18 <= p <= 1e6):
        return 0.0, False
    if src == "implied" and reserve / 10 ** d * p < 1:  # dust-implied noise
        return 0.0, False
    return reserve / 10 ** d * p, True

tvl_corr = 0.0; tvl_hard = 0.0
for p in v2:
    v0, ok0 = side_usd(p["token0"], p["reserve0"])
    v1, ok1 = side_usd(p["token1"], p["reserve1"])
    tvl_corr += v0 + v1
    if p["priced_both"]:
        tvl_hard += p["tvl_usd"]

# --- excess across all sources ---
excess_rows = []
for p in v2:
    if p["excess_usd"] > 0 or (p.get("excess0") or 0) > 0 or (p.get("excess1") or 0) > 0:
        excess_rows.append({"src": "ci-v2", "pair": p["pair"], "e0": p["excess0"], "e1": p["excess1"],
                            "usd": p["excess_usd"], "s0": p["sym0"], "s1": p["sym1"]})
for tag, g in (("gap1", g1), ("gap2", g2), ("gap3", g3)):
    for e in g["excess_pairs"]:
        excess_rows.append({"src": tag, "pair": e["pair"], "e0": e["excess0"], "e1": e["excess1"],
                            "usd": None, "t0": e["token0"], "t1": e["token1"]})

# value the USD+ dust precisely (6 decimals, assume $1 conservative)
usd_plus = "0xb79dd08ea68a908a97220c76d19a6aa9cbde4376"
usd_plus_dust = 0
for e in excess_rows:
    for side_tok, side_e in ((e.get("t1") or e.get("token1"), e.get("e1")),
                             (e.get("t0") or e.get("token0"), e.get("e0"))):
        if side_tok and side_tok.lower() == usd_plus and side_e:
            usd_plus_dust += side_e
usd_plus_usd = usd_plus_dust / 1e6  # 6 decimals, $1 assumption (upper bound)

# --- coverage ---
def full_ok(rows, t0k="token0", t1k="token1", r0k="reserve0", r1k="reserve1", b0k="balance0", b1k="balance1"):
    return {r["pair"].lower() for r in rows
            if r.get(r0k) is not None and r.get(r1k) is not None
            and r.get(b0k) is not None and r.get(b1k) is not None}

checked = full_ok(v2) | full_ok(g1["rows"]) | full_ok(g2["rows"]) | full_ok(g3["rows"])
all_pairs = 8290
coverage = len(checked)

# --- masterchef actual staked value (merge tvl map from v2 + estimated top pairs) ---
tvl_map = {p["pair"].lower(): p["tvl_usd"] for p in v2}
sup_map = {p["pair"].lower(): p["totalSupply"] for p in v2}
mc_rows = []
mc_total = 0.0
for p in mc["pools"]:
    lp = (p.get("lpToken") or "").lower()
    tvl = tvl_map.get(lp); ts = sup_map.get(lp); bal = p.get("mcBalance") or 0
    val = (tvl * bal / ts) if (tvl and ts) else None
    if val: mc_total += val
    mc_rows.append({"pid": p["pid"], "lpToken": p["lpToken"], "allocPoint": p["allocPoint"],
                    "totalDeposit": p["totalDeposit"], "mcBalance": bal,
                    "pair_tvl_usd": tvl, "staked_usd": round(val, 2) if val else None})

# --- stuck min-liquidity ---
stuck = [p for p in v2 if p["totalSupply"] == 1000 and p["tvl_usd"] > 0]
stuck_usd = sum(p["tvl_usd"] for p in stuck)

out = {
    "block_ci_v2": scan["block"],
    "coverage_pairs_fully_checked": coverage,
    "coverage_total": all_pairs,
    "coverage_pct": round(100 * coverage / all_pairs, 2),
    "tvl_corrected_usd": round(tvl_corr, 2),
    "tvl_hard_priced_usd": round(tvl_hard, 2),
    "excess_pairs_total": len(excess_rows),
    "excess_usd_upper_bound": round(usd_plus_usd + 1e-9, 6),
    "excess_rows": excess_rows,
    "usd_plus_dust_raw": usd_plus_dust,
    "masterchef_actual_staked_usd": round(mc_total, 2),
    "masterchef_rows": mc_rows,
    "stuck_min_liquidity_pairs": len(stuck),
    "stuck_min_liquidity_usd": round(stuck_usd, 2),
}
json.dump(out, open(os.path.join(AN, "final_numbers.json"), "w"), indent=1)

print("coverage:", coverage, "/", all_pairs, f"({out['coverage_pct']}%)")
print("TVL corrected:", out["tvl_corrected_usd"], "| hard:", out["tvl_hard_priced_usd"])
print("excess pairs:", len(excess_rows), "| USD+ dust raw:", usd_plus_dust, "= $", round(usd_plus_usd, 6))
print("MasterChef actual staked USD:", out["masterchef_actual_staked_usd"])
print("stuck pairs:", len(stuck), "USD:", out["stuck_min_liquidity_usd"])
print("excess rows:")
for e in excess_rows:
    print(" ", e)
