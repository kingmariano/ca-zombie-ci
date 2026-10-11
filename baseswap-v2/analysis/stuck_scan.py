#!/usr/bin/env python3
"""Full-pairs scan of LP balances at address(0)/0xdead -> permanently locked reserves (S).

RPC from env RPC_GAPFILL (never persisted). Writes analysis/stuck_scan.json
"""
import json, os, time
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("fm", os.path.join(ROOT, "analysis", "fill_missing.py"))
fm = importlib.util.module_from_spec(spec)
src = open(os.path.join(ROOT, "analysis", "fill_missing.py")).read().replace(
    'if __name__ == "__main__":\n    main()', '')
import types
fm = types.ModuleType("fm")
fm.__dict__["__file__"] = os.path.join(ROOT, "analysis", "fill_missing.py")
exec(compile(src, "fill_missing.py", "exec"), fm.__dict__)
batch, du, da, enc_addr = fm.batch, fm.du, fm.da, fm.enc_addr
SEL = fm.SEL

ZERO = "0x0000000000000000000000000000000000000000"
DEAD = "0x000000000000000000000000000000000000dEaD"

v2 = json.load(open(os.path.join(ROOT, "analysis", "ci2-backup", "pairs.json")))
tok = json.load(open(os.path.join(ROOT, "analysis", "ci2-backup", "tokens.json")))
prices, meta = tok["prices"], tok["tokens"]
g1 = json.load(open(os.path.join(ROOT, "analysis", "missing_scan.json")))["rows"]
g2 = json.load(open(os.path.join(ROOT, "analysis", "missing_scan2.json")))["rows"]
g3 = json.load(open(os.path.join(ROOT, "analysis", "missing_scan3.json")))["rows"]

state = {}
for r in v2:
    state[r["pair"].lower()] = {"t0": r["token0"], "t1": r["token1"], "r0": r["reserve0"],
                                "r1": r["reserve1"], "sup": r["totalSupply"]}
for rows in (g1, g2, g3):
    for r in rows:
        state.setdefault(r["pair"].lower(), {"t0": r.get("token0"), "t1": r.get("token1"),
                                             "r0": r.get("reserve0"), "r1": r.get("reserve1"),
                                             "sup": r.get("totalSupply")})
print("pairs with state:", len(state), flush=True)

def side_usd(t, reserve, hard_only=False):
    if not t or reserve is None:
        return 0.0
    p = prices.get(t.lower()); d = meta.get(t.lower(), {}).get("decimals")
    if p is None or d is None:
        return 0.0
    src = meta.get(t.lower(), {}).get("price_source")
    if hard_only and src == "implied":
        return 0.0
    if src == "implied" and not (1e-18 <= p <= 1e6):
        return 0.0
    return reserve / 10 ** d * p

pairs = sorted(state.keys())
calls = []
for p in pairs:
    calls.append((p, SEL["balanceOf"] + enc_addr(ZERO)))
    calls.append((p, SEL["balanceOf"] + enc_addr(DEAD)))
r = batch(calls, chunk=50, workers=3)
rows = []
tot_locked_usd = 0.0
tot_locked_hard_usd = 0.0
for i, p in enumerate(pairs):
    b0 = du(r[2 * i]); bd = du(r[2 * i + 1])
    st = state[p]; sup = st["sup"]
    if not sup:
        continue
    locked = (b0 or 0) + (bd or 0)
    if locked <= 1000:  # only MINIMUM_LIQUIDITY
        continue
    share = locked / sup
    v0 = side_usd(st["t0"], st["r0"]); v1 = side_usd(st["t1"], st["r1"])
    h0 = side_usd(st["t0"], st["r0"], hard_only=True); h1 = side_usd(st["t1"], st["r1"], hard_only=True)
    locked_usd = share * (v0 + v1)
    locked_hard = share * (h0 + h1)
    tot_locked_usd += locked_usd
    tot_locked_hard_usd += locked_hard
    rows.append({"pair": p, "t0": st["t0"], "t1": st["t1"], "totalSupply": sup,
                 "locked_lp": locked, "locked_share": round(share, 6),
                 "locked_usd": round(locked_usd, 2), "locked_hard_usd": round(locked_hard, 2),
                 "pair_usd": round(v0 + v1, 2),
                 "s0": meta.get((st["t0"] or "").lower(), {}).get("symbol"),
                 "s1": meta.get((st["t1"] or "").lower(), {}).get("symbol")})
rows.sort(key=lambda x: -x["locked_usd"])
out = {"pairs_with_locked_lp": len(rows),
       "locked_usd_total": round(tot_locked_usd, 2),
       "locked_hard_usd_total": round(tot_locked_hard_usd, 2),
       "top_locked": rows[:30]}
json.dump(out, open(os.path.join(ROOT, "analysis", "stuck_scan.json"), "w"), indent=1)
print("pairs with >1000 LP at zero/dead:", len(rows))
print("TOTAL locked reserve value: $%.2f (hard-priced only: $%.2f)" % (tot_locked_usd, tot_locked_hard_usd))
for x in rows[:15]:
    print(f"  {x['pair']} {x['s0']}/{x['s1']} share {x['locked_share']*100:.2f}% locked ${x['locked_usd']:,.2f} (pair ${x['pair_usd']:,.2f})")
