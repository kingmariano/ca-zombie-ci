#!/usr/bin/env python3
"""Value the NarwhalCollecter holdings using state-dump + DefiLlama prices."""
import json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Mozilla/5.0 zombie-ci"}

d = json.load(open(os.path.join(HERE, "state-dump.json")))
col = json.load(open(os.path.join(HERE, "collecter-state.json")))
tok = d["tokens"]

def llama(addrs):
    out = {}
    B = 40
    for i in range(0, len(addrs), B):
        url = "https://coins.llama.fi/prices/current/" + ",".join("bsc:" + a for a in addrs[i:i+B])
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=25) as r:
                j = json.loads(r.read())
            for k, v in j.get("coins", {}).items():
                out[k.split(":", 1)[1].lower()] = v["price"]
        except Exception as e:
            print("llama fail", str(e)[:80], file=sys.stderr)
    return out

def dec(t): return (tok.get(t) or {}).get("decimals") or 18
def sym(t): return (tok.get(t) or {}).get("symbol")

alltoks = set()
for p, lp in col["lp_balances"].items():
    v = d["pairs"][p]
    alltoks.add(v["token0"]); alltoks.add(v["token1"])
alltoks |= set(col["token_balances"].keys())
prices = llama(sorted(alltoks))

rows = []
tot = 0.0
for p, lp in sorted(col["lp_balances"].items(), key=lambda kv: -kv[1]):
    v = d["pairs"][p]
    t0, t1 = v["token0"], v["token1"]
    ts = v["totalSupply"] or 1
    share = lp / ts
    r0 = (v["reserve0"] or 0) / 10**dec(t0)
    r1 = (v["reserve1"] or 0) / 10**dec(t1)
    p0, p1 = prices.get(t0), prices.get(t1)
    usd = (r0*share*p0 if p0 else 0) + (r1*share*p1 if p1 else 0)
    tot += usd
    rows.append({"pair": p, "sym0": sym(t0), "sym1": sym(t1), "lp": lp, "share": share,
                 "usd": usd, "r0": r0, "r1": r1,
                 "claim0": r0*share, "claim1": r1*share, "p0": p0, "p1": p1})
rows.sort(key=lambda r: -r["usd"])
print(f"LP holdings value: ${tot:,.2f} across {len(rows)} pairs")
print("\nTOP 15 LP POSITIONS:")
for r in rows[:15]:
    print(f'  {r["pair"]} {r["sym0"]}/{r["sym1"]} share={r["share"]:.6f} usd=${r["usd"]:,.2f} '
          f'claim=({r["claim0"]:.6g},{r["claim1"]:.6g})')

tb = col["token_balances"]
tbt = 0.0
print("\nDIRECT TOKEN BALANCES:")
for t, b in sorted(tb.items(), key=lambda kv: -kv[1]):
    amt = b / 10**dec(t)
    pr = prices.get(t)
    v = amt*pr if pr else 0
    tbt += v
    print(f"  {sym(t)} {t} amt={amt:.8g} price={pr} usd=${v:,.2f}")
print(f"\ncollecter total (LP + direct): ${tot+tbt:,.2f}")
out = {"lp_rows": rows, "lp_total_usd": tot, "token_balances": {t: {"amount": b/10**dec(t), "usd": (b/10**dec(t))*(prices.get(t) or 0)} for t, b in tb.items()},
       "token_total_usd": tbt, "total_usd": tot+tbt, "prices": prices}
json.dump(out, open(os.path.join(HERE, "collecter-value.json"), "w"), indent=1)
print("wrote collecter-value.json")
