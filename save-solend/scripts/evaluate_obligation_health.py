#!/usr/bin/env python3
"""Evaluate current liquidatability + profit for main-market sane liquidatable obligations."""
import json

AN = "/home/heisenberg/CA/save-solend/analysis"
st = json.load(open("/tmp/opencode/solend_state_v2.json"))
px = json.load(open(f"{AN}/prices.json"))["prices"]
sim = {s["reserve"]: s for s in json.load(open("/tmp/opencode/simsolend/out_all.json")) if s.get("reserve")}
full = json.load(open("/tmp/opencode/main_sane_liq_fixed_full.json"))
resrows = {r["reserve"]: r for r in json.load(open(f"{AN}/reserves.json"))}
cfgrows = st["cfgRows"]
rawres = st["reservesRaw"]

def wad(x): return x / 1e18
def sim_prices(rk):
    s = sim.get(rk)
    if not s or not s.get("ok") or not s.get("post"): return None
    return (int(s["post"]["marketPriceWads"]) / 1e18, int(s["post"]["smoothedPriceWads"]) / 1e18)

RD = {}
for rk, r in rawres.items():
    if "err" in r: continue
    dec = r["mintDecimals"]
    sp = sim_prices(rk)
    stored_market = wad(r["marketPrice"]); stored_sm = wad(r["smoothedMarketPrice"])
    cur_market, cur_sm = sp if sp else (stored_market, stored_sm)
    lo, hi = min(cur_market, cur_sm), max(cur_market, cur_sm)
    if r["extraMarketPrice"] is not None:
        lo = min(lo, wad(r["extraMarketPrice"])); hi = max(hi, wad(r["extraMarketPrice"]))
    total_liq = r["availableAmount"] + wad(r["borrowedAmountWads"]) - wad(r["config"]["accumulatedProtocolFeesWads"])
    csup = r["collateralMintTotalSupply"] / 10**dec
    exch = (total_liq / 10**dec) / csup if csup > 0 else 1.0
    RD[rk] = {"dec": dec, "cur_market": cur_market, "lo": lo, "hi": hi,
              "cur_rate": wad(r["cumulativeBorrowRateWads"]), "exch": exch,
              "real": (px.get(r["mint"]) or {}).get("usd"), "bw": 1 + r["config"]["addedBorrowWeightBps"] / 10000,
              "ltv": r["config"]["loanToValueRatio"] / 100, "thr": r["config"]["liquidationThreshold"] / 100,
              "mthr": r["config"]["maxLiquidationThreshold"] / 100, "bonus": r["config"]["liquidationBonus"] / 100,
              "mbonus": r["config"]["maxLiquidationBonus"] / 100, "plf": r["config"]["protocolLiquidationFee"] / 1000,
              "symbol": cfgrows.get(rk, {}).get("liquidityToken", {}).get("symbol"), "refreshable": sp is not None,
              "stale": r["lastUpdate"]["stale"]}

ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n: n, r = divmod(n, 58); s = ALPH[r] + s
    return "1" * (len(b) - len(b.lstrip(b"\0"))) + (s or "")

def decode_obl(hx):
    b = bytes.fromhex(hx)
    o = {"deposits": [], "borrows": []}
    off = 204
    for _ in range(b[202]):
        o["deposits"].append({"reserve": b58(b[off:off+32]), "amount": int.from_bytes(b[off+32:off+40], "little")}); off += 88
    for _ in range(b[203]):
        o["borrows"].append({"reserve": b58(b[off:off+32]), "cum": int.from_bytes(b[off+32:off+48], "little"),
                             "amount": int.from_bytes(b[off+48:off+64], "little")}); off += 112
    return o

funnel = {"fetched": len(full), "decoded": 0, "withBorrowValue": 0, "liquidatable": 0, "allRefreshable": 0, "profitable": 0}
results = []
for obl, hx in full.items():
    try: comp = decode_obl(hx)
    except Exception: continue
    funnel["decoded"] += 1
    if any(d["reserve"] not in RD for d in comp["deposits"] + comp["borrows"]): continue
    dep_v = dep_lo = dep_u = dep_su = 0.0
    for d in comp["deposits"]:
        rd = RD[d["reserve"]]
        tok = d["amount"] / 10**rd["dec"] * rd["exch"]
        v = tok * rd["cur_market"]; vlo = tok * rd["lo"]
        dep_v += v; dep_lo += vlo * rd["ltv"]; dep_u += v * rd["thr"]; dep_su += v * rd["mthr"]
    bor_v = bor_ub = 0.0
    for br in comp["borrows"]:
        rd = RD[br["reserve"]]
        debt = wad(br["amount"]) * (rd["cur_rate"] / wad(br["cum"])) / 10**rd["dec"]
        v = debt * rd["cur_market"]
        bor_v += v * rd["bw"]; bor_ub += debt * rd["hi"] * rd["bw"]
    if bor_v <= 0: continue
    funnel["withBorrowValue"] += 1
    unhealthy = min(dep_u, 70e6); super_un = min(dep_su, 70e6); allowed = min(dep_lo, 65e6)
    if not (unhealthy > 0 and bor_v >= unhealthy): continue
    funnel["liquidatable"] += 1
    # gate: every reserve refreshable
    allres = [d["reserve"] for d in comp["deposits"]] + [br["reserve"] for br in comp["borrows"]]
    if not all(RD[rk]["refreshable"] for rk in allres): continue
    funnel["allRefreshable"] += 1
    repay = max(comp["borrows"], key=lambda x: RD[x["reserve"]]["bw"])
    rrk = repay["reserve"]; rrd = RD[rrk]
    max_repay_prog = min(bor_v * 0.20, 500000.0)
    if rrd["cur_market"] <= 0: continue
    repay_tokens = min(max_repay_prog / rrd["cur_market"],
                       wad(repay["amount"]) * (rrd["cur_rate"] / wad(repay["cum"])) / 10**rrd["dec"])
    if repay_tokens <= 0: continue
    if super_un <= unhealthy or abs(super_un - unhealthy) < 1e-9:
        total_bonus = min(rrd["bonus"] + rrd["plf"], 0.25)
    else:
        w = max(0.0, min(1.0, (bor_v - unhealthy) / (super_un - unhealthy)))
        total_bonus = min(rrd["bonus"] + w * (rrd["mbonus"] - rrd["bonus"]) + rrd["plf"], 0.25)
    seize_prog = repay_tokens * rrd["cur_market"] * (1 + total_bonus)
    best = None
    for d in comp["deposits"]:
        cd = RD[d["reserve"]]
        dep_tok = d["amount"] / 10**cd["dec"] * cd["exch"]
        if dep_tok <= 0 or cd["cur_market"] <= 0: continue
        seize_tokens = min(dep_tok, seize_prog / cd["cur_market"])
        if cd["real"] is None or rrd["real"] is None: continue
        gross = seize_tokens * cd["real"] - repay_tokens * rrd["real"]
        fee = seize_tokens * cd["real"] * (rrd["plf"] / (1 + total_bonus))
        net = gross - fee
        if best is None or net > best["net"]:
            best = {"coll": cd["symbol"], "collReserve": d["reserve"], "collProg": cd["cur_market"], "collReal": cd["real"],
                    "seizeTokens": seize_tokens, "net": net, "gross": gross, "depTokens": dep_tok}
    if not best: continue
    funnel["profitable"] += 1 if best["net"] > 0 else funnel["profitable"]
    results.append({"obligation": obl, "borrowedNow": bor_v, "unhealthyNow": unhealthy, "superUn": super_un, "allowedNow": allowed,
                    "ratio": bor_v / unhealthy, "repaySymbol": rrd["symbol"], "repayTokens": repay_tokens,
                    "repayProg": repay_tokens * rrd["cur_market"], "repayReal": repay_tokens * rrd["real"],
                    "bonus": total_bonus, "best": best, "netProfit": best["net"], "nDep": len(comp["deposits"]), "nBor": len(comp["borrows"])})

results.sort(key=lambda r: -r["netProfit"])
json.dump({"funnel": funnel, "results": results}, open(f"{AN}/main-liquidation-now2.json", "w"), indent=1)
print("FUNNEL:", funnel)
pos = [r for r in results if r["netProfit"] > 0]
print(f"profitable obligations: {len(pos)}  sum net (single 20% call): ${sum(r['netProfit'] for r in pos):,.0f}")
print(f"{'obligation':20} {'borrowedNow$':>13} {'ratio':>6} {'repay':>8} {'repayProg$':>11} {'bonus':>6} {'coll':>9} {'collReal':>10} {'net$':>11}")
for r in results[:30]:
    b = r["best"]
    print(f"{r['obligation'][:20]:20} {r['borrowedNow']:13,.0f} {r['ratio']:6.2f} {str(r['repaySymbol'])[:8]:>8} {r['repayProg']:11,.0f} {r['bonus']:6.3f} {str(b['coll'])[:9]:>9} {b['collReal']:10.4f} {r['netProfit']:11,.0f}")
