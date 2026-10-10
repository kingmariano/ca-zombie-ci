#!/usr/bin/env python3
"""Compute per-pair USD TVL + Fees-contract token balances at pinned block; write pairs_priced.json."""
import json, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from sn import call

def u256(felts):
    if felts is None: return None
    if len(felts) == 2:
        return int(felts[0], 16) + (int(felts[1], 16) << 128)
    return int(felts[0], 16)

d = json.load(open("pairs_raw.json"))
meta = json.load(open("tokens_meta.json"))
pairs = [p for p in d["pairs"] if p.get("pair") not in (None, "0x0") and "error" not in p]
tokens = sorted({t for p in pairs for t in p["tokens"]})

# DefiLlama prices
prices = {}
for i in range(0, len(tokens), 20):
    chunk = tokens[i:i+20]
    keys = ",".join("starknet:" + a for a in chunk)
    try:
        with urllib.request.urlopen("https://coins.llama.fi/prices/current/" + keys, timeout=30) as r:
            j = json.loads(r.read())
        for k, v in j.get("coins", {}).items():
            prices[k.split(":", 1)[1]] = v
    except Exception as e:
        print("price err", e)
    time.sleep(0.3)
json.dump(prices, open("prices.json", "w"), indent=1)
print("priced tokens:", len(prices), "of", len(tokens))

# Fees-contract balances
def fees_balances(p):
    try:
        fc = int(p["fees_contract"], 16)
        bals = []
        for t in p["tokens"]:
            b = u256(call(int(t, 16), "balanceOf", [hex(fc)]))
            bals.append(b)
        return p["pair"], bals
    except Exception as e:
        return p["pair"], {"error": str(e)[:100]}

with ThreadPoolExecutor(max_workers=4) as ex:
    for f in as_completed([ex.submit(fees_balances, p) for p in pairs]):
        addr, bals = f.result()
        for p in pairs:
            if p["pair"] == addr:
                p["fees_balances"] = bals

def usd(addr, amt):
    m = meta.get(addr)
    if not m or "decimals" not in m: return None
    p = prices.get(addr)
    if not p: return None
    return amt / (10**m["decimals"]) * p["price"]

tot = 0.0; tot_fees = 0.0
for p in pairs:
    v = 0.0; fv = 0.0; ok = True
    for t, r in zip(p["tokens"], p["reserves"]):
        x = usd(t, r)
        if x is None: ok = False
        else: v += x
    fb = p.get("fees_balances")
    if isinstance(fb, list):
        for t, b in zip(p["tokens"], fb):
            x = usd(t, b)
            if x is not None: fv += x
    p["usd"] = round(v, 2); p["usd_complete"] = ok; p["fees_usd"] = round(fv, 2)
    tot += v; tot_fees += fv
pairs.sort(key=lambda x: -x["usd"])
print(f"TOTAL TVL (all priced): {tot:,.2f} USD")
print(f"TOTAL FEES CONTRACT balances: {tot_fees:,.2f} USD")
print("top 30 by TVL:")
for p in pairs[:30]:
    t0, t1 = p["tokens"]
    m0, m1 = meta[t0], meta[t1]
    print(f"  pid={p['pid']:3d} {p['pair'][:16]} stable={p['stable']} fee={p['fee0']:>5} tvl={p['usd']:>10,.2f} fees={p['fees_usd']:>9,.2f}  {m0['symbol']:>8} {p['reserves'][0]/10**m0['decimals']:>14.4f} | {m1['symbol']:>8} {p['reserves'][1]/10**m1['decimals']:>14.4f}")
print("top 15 by FEES balances:")
for p in sorted(pairs, key=lambda x: -x["fees_usd"])[:15]:
    t0, t1 = p["tokens"]
    m0, m1 = meta[t0], meta[t1]
    fb = p.get("fees_balances") or [0,0]
    print(f"  pid={p['pid']:3d} {p['pair'][:16]} fees_usd={p['fees_usd']:>9,.2f} fees_bal={fb[0]/10**m0['decimals']:.6f} {m0['symbol']} + {fb[1]/10**m1['decimals']:.6f} {m1['symbol']}")
unp = [p for p in pairs if not p["usd_complete"]]
print("unpriced pairs:", len(unp))
for p in unp[:10]:
    print("  ", p["pair"], [meta.get(t,{}).get("symbol", t[:12]) for t in p["tokens"]], p["reserves"])
json.dump({"block": d["block"], "pairs": pairs, "meta": meta, "prices": prices}, open("pairs_priced.json", "w"), indent=1)
