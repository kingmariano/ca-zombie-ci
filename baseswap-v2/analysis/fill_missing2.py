#!/usr/bin/env python3
"""Final gap-fill: check the pairs not yet fully checked (reserves+balances).
RPC from env RPC_GAPFILL (never persisted). Writes analysis/missing_scan2.json
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
spec = importlib.util.spec_from_file_location("fm", os.path.join(os.path.dirname(os.path.abspath(__file__)), "fill_missing.py"))
fm = importlib.util.module_from_spec(spec)
# do not execute main(); load module code
import types
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "fill_missing.py")).read()
src = src.replace('if __name__ == "__main__":\n    main()', '')
mod = types.ModuleType("fm"); mod.__dict__["__file__"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fill_missing.py")
exec(compile(src, "fill_missing.py", "exec"), mod.__dict__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
checked = set(json.load(open(os.path.join(ROOT, "analysis", "checked_pairs.json"))))
SEL = mod.SEL; batch = mod.batch; du = mod.du; da = mod.da; enc_uint = mod.enc_uint; enc_addr = mod.enc_addr
FACTORY = mod.FACTORY
import time

def main():
    t0 = time.time()
    calls = [(FACTORY, SEL["allPairs"] + enc_uint(i)) for i in range(8290)]
    res = batch(calls, chunk=50, workers=3)
    all_pairs = [da(r).lower() for r in res if da(r)]
    print("allPairs:", len(all_pairs), "in", round(time.time() - t0, 1), flush=True)
    todo = [p for p in all_pairs if p not in checked]
    print("unchecked to scan:", len(todo), flush=True)
    calls = []
    for p in todo:
        calls += [(p, SEL["token0"]), (p, SEL["token1"]), (p, SEL["getReserves"]), (p, SEL["totalSupply"])]
    r = batch(calls, chunk=50, workers=3)
    rows = []
    calls_bal = []; idx_bal = []
    for i, p in enumerate(todo):
        t0_ = da(r[4 * i]); t1_ = da(r[4 * i + 1]); rv = r[4 * i + 2]; sup = du(r[4 * i + 3])
        res0 = res1 = None
        if rv and len(rv) >= 194:
            res0 = int(rv[2:66], 16); res1 = int(rv[66:130], 16)
        row = {"pair": p, "token0": t0_, "token1": t1_, "reserve0": res0, "reserve1": res1, "totalSupply": sup}
        rows.append(row)
        if t0_:
            calls_bal.append((t0_, SEL["balanceOf"] + enc_addr(p))); idx_bal.append((i, 0))
        if t1_:
            calls_bal.append((t1_, SEL["balanceOf"] + enc_addr(p))); idx_bal.append((i, 1))
    rb = batch(calls_bal, chunk=50, workers=3)
    for (i, side), v in zip(idx_bal, rb):
        rows[i]["balance0" if side == 0 else "balance1"] = du(v)
    excess = []
    for row in rows:
        e0 = (row["balance0"] - row["reserve0"]) if (row.get("balance0") is not None and row["reserve0"] is not None) else None
        e1 = (row["balance1"] - row["reserve1"]) if (row.get("balance1") is not None and row["reserve1"] is not None) else None
        row["excess0"] = e0; row["excess1"] = e1
        if (e0 and e0 > 0) or (e1 and e1 > 0):
            excess.append(row)
    stats = {
        "all_pairs": len(all_pairs), "previously_checked": len(checked), "scanned_now": len(todo),
        "with_tokens": len([r for r in rows if r["token0"] and r["token1"]]),
        "with_reserves": len([r for r in rows if r["reserve0"] is not None]),
        "with_balances": len([r for r in rows if r.get("balance0") is not None and r.get("balance1") is not None]),
        "zero_supply": len([r for r in rows if r["totalSupply"] == 0]),
        "excess_pairs": len(excess), "elapsed_s": round(time.time() - t0, 1), "rpc": "<redacted>",
    }
    json.dump({"stats": stats, "excess_pairs": excess, "rows": rows},
              open(os.path.join(ROOT, "analysis", "missing_scan2.json"), "w"))
    print("STATS", json.dumps(stats), flush=True)
    for e in excess:
        print("EXCESS", json.dumps(e), flush=True)

if __name__ == "__main__":
    main()
