#!/usr/bin/env python3
"""Value JediSwap V1 pair reserves + skim excess at DefiLlama prices (public API)."""
import json, urllib.request, urllib.error, time, sys

BASE = "/home/heisenberg/CA/jediswap-v1/analysis/"
st = json.load(open(BASE + "pair_state.json"))
pairs = st["pairs"]

# token meta from a quick direct fetch if token_meta.json missing
try:
    meta = json.load(open(BASE + "token_meta.json"))
except Exception:
    meta = {}

tokens = sorted({p.get("token0") for p in pairs if p.get("token0")} |
                {p.get("token1") for p in pairs if p.get("token1")})
print("unique tokens:", len(tokens))


def http(url, timeout=45):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def fetch_prices(tokens):
    out = {}
    chunk = 50
    for i in range(0, len(tokens), chunk):
        part = tokens[i:i + chunk]
        keys = ",".join(f"starknet:{t}" for t in part)
        url = f"https://coins.llama.fi/prices/current/{keys}"
        for attempt in range(3):
            try:
                d = http(url)
                out.update(d.get("coins", {}))
                break
            except Exception as e:
                time.sleep(1.5 * (attempt + 1))
        print("price chunk", i, "->", len(out))
    return out


prices = fetch_prices(tokens)
json.dump(prices, open(BASE + "prices_llama.json", "w"), indent=1)

# symbol/decimals: use meta if present else fetch quickly for the tokens we need
import sn
need_meta = [t for t in tokens if t not in meta or "decimals" not in meta.get(t, {})]
if need_meta:
    print("fetching meta for", len(need_meta), "tokens")
    sym_sel = sn.selector("symbol"); dec_sel = sn.selector("decimals")
    calls = []
    for t in need_meta:
        calls.append((t, dec_sel, [])); calls.append((t, sym_sel, []))
    res = sn.batch_calls(calls, chunk=100)
    for i, t in enumerate(need_meta):
        d = res[2*i]; s = res[2*i+1]
        rec = meta.get(t, {})
        if isinstance(d, list) and d:
            try: rec["decimals"] = int(d[0], 16)
            except Exception: pass
        if isinstance(s, list) and s:
            try:
                b = bytes.fromhex(s[0][2:]); rec["symbol"] = b.decode("utf-8", "ignore").strip("\x00")
            except Exception: rec["symbol_raw"] = s[0]
        meta[t] = rec
    json.dump(meta, open(BASE + "token_meta.json", "w"), indent=1)

total_usd = 0.0
priced = 0
unpriced = {}
per_pair = []
for p in pairs:
    rec = {"pair": p["pair"], "usd": 0.0, "legs": []}
    for side, tkey, rkey in (("0", "token0", "reserve0"), ("1", "token1", "reserve1")):
        t = p.get(tkey); raw = int(p.get(rkey, 0))
        if not t or raw == 0:
            continue
        dec = meta.get(t, {}).get("decimals", 18)
        amt = raw / (10 ** dec)
        pr = prices.get(f"starknet:{t}")
        if pr:
            usd = amt * pr["price"]
            total_usd += usd
            priced += 1
            rec["usd"] += usd
            rec["legs"].append({"side": side, "token": t, "symbol": meta.get(t, {}).get("symbol"),
                                "amount": str(raw), "usd": round(usd, 2), "price": pr["price"]})
        else:
            unpriced[t] = unpriced.get(t, 0) + raw
            rec["legs"].append({"side": side, "token": t, "symbol": meta.get(t, {}).get("symbol"),
                                "amount": str(raw), "usd": None})
    per_pair.append(rec)

print("TOTAL TVL USD (reserves, priced legs only):", round(total_usd, 2), "priced legs:", priced)
print("unpriced tokens:", len(unpriced))
for t, raw in list(unpriced.items())[:20]:
    print("  ", t, meta.get(t, {}).get("symbol"), raw)
json.dump({"total_usd": round(total_usd, 2), "per_pair": per_pair, "unpriced": {k: str(v) for k, v in unpriced.items()}},
          open(BASE + "valuation.json", "w"), indent=1)

# skim excess valuation
excess_usd = 0.0
ex_rows = []
for p in pairs:
    b0 = int(p.get("balance0", 0)); r0 = int(p.get("reserve0", 0))
    b1 = int(p.get("balance1", 0)); r1 = int(p.get("reserve1", 0))
    e0 = b0 - r0; e1 = b1 - r1
    if e0 <= 0 and e1 <= 0:
        continue
    row = {"pair": p["pair"], "e0": e0, "e1": e1, "usd": 0.0}
    for e, t in ((e0, p.get("token0")), (e1, p.get("token1"))):
        if e <= 0 or not t:
            continue
        dec = meta.get(t, {}).get("decimals", 18)
        pr = prices.get(f"starknet:{t}")
        if pr:
            u = (e / (10 ** dec)) * pr["price"]
            row["usd"] += u
            excess_usd += u
    ex_rows.append(row)
print("TOTAL skim-excess USD:", round(excess_usd, 2))
for r in ex_rows:
    print("  ", r["pair"], "e0", r["e0"], "e1", r["e1"], "usd", round(r["usd"], 4))
json.dump({"excess_usd": round(excess_usd, 2), "rows": ex_rows}, open(BASE + "skim_excess.json", "w"), indent=1)
