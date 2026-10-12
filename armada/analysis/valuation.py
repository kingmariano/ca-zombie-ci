#!/usr/bin/env python3
"""Valuation: token vault balances + Orca whirlpool position values, priced via DefiLlama."""
import base64, json, math, sys, time
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
import requests

A = "/home/heisenberg/CA/armada/analysis"
r1 = json.load(open(f"{A}/recon1.json"))
r2 = json.load(open(f"{A}/recon2.json"))
acc = r2["accounts"]
vaults = r1["vaults"]

# --- fetch CLP (whirlpool) accounts ---
clps = sorted({v["clp"] for v in vaults.values()})
res = get_accounts(clps, encoding="base64")
wp = {}
for k, a in zip(clps, res):
    if not a:
        wp[k] = None; continue
    raw = base64.b64decode(a["data"][0])
    if len(raw) == 653:
        wp[k] = {"len": len(raw), "owner": a["owner"],
                 "liquidity": int.from_bytes(raw[41:57], "little"),
                 "sqrt_price": int.from_bytes(raw[57:73], "little"),
                 "tick_current": int.from_bytes(raw[73:77], "little", signed=True),
                 "token_mint_a": b58encode(raw[93:125]), "token_vault_a": b58encode(raw[125:157]),
                 "token_mint_b": b58encode(raw[173:205]), "token_vault_b": b58encode(raw[205:237])}
    else:
        wp[k] = {"len": len(raw), "owner": a["owner"], "raw_head": raw[:64].hex()}
print("clp lens:", {k: (v or {}).get("len") for k, v in wp.items()})

Q64 = 1 << 64
def sqrt_at_tick(tick):
    return math.isqrt(int(1.0001 ** (tick / 2) * Q64 ** 2))  # integer sqrt price Q64.64

def pos_amounts(L, tl, tu, tc, sqrtP):
    pa = 1.0001 ** (tl / 2) * Q64
    pb = 1.0001 ** (tu / 2) * Q64
    P = sqrtP / Q64
    pa_, pb_, P_ = pa / Q64, pb / Q64, sqrtP / Q64
    if P_ <= pa_:
        amt_a = L * (pb_ - pa_) / (pa_ * pb_)
        amt_b = 0.0
    elif P_ >= pb_:
        amt_a = 0.0
        amt_b = L * (pb_ - pa_)
    else:
        amt_a = L * (pb_ - P_) / (P_ * pb_)
        amt_b = L * (P_ - pa_)
    return int(amt_a), int(amt_b)

# --- collect all mints and price them ---
mints = set()
for v in vaults.values():
    mints.add(v["token_mint_a"]); mints.add(v["token_mint_b"])
mints = sorted(mints)

def llama_prices(ms):
    out = {}
    for i in range(0, len(ms), 50):
        chunk = ms[i:i+50]
        q = ",".join(f"solana:{m}" for m in chunk)
        for attempt in range(3):
            try:
                r = requests.get(f"https://coins.llama.fi/prices/current/{q}", timeout=30)
                j = r.json()
                for k, v in (j.get("coins") or {}).items():
                    out[k.split(":", 1)[1]] = v
                break
            except Exception as e:
                time.sleep(2)
    return out

prices = llama_prices(mints)
# symbol lookup via dexscreener for unpriced
symbols = {}
for m in mints:
    if m in prices:
        symbols[m] = prices[m].get("symbol")
for m in mints:
    if m not in prices:
        try:
            r = requests.get(f"https://api.dexscreener.com/latest/dex/tokens/{m}", timeout=25)
            j = r.json()
            pairs = j.get("pairs") or []
            if pairs:
                symbols[m] = pairs[0].get("baseToken", {}).get("symbol")
                p = pairs[0].get("priceUsd")
                if p:
                    prices[m] = {"price": float(p), "symbol": symbols[m], "source": "dexscreener"}
        except Exception:
            pass
        time.sleep(0.3)

# decimals from earlier recon3
r3 = json.load(open(f"{A}/recon3_mints.json"))
decs = {m: v["decimals"] for m, v in r3["pair_mints"].items() if v and "decimals" in v}

out = {"vaults": {}, "prices": prices, "symbols": symbols}
total_usd = 0.0
unpriced = []
for vk, v in vaults.items():
    va, vb = v["token_vault_a"], v["token_vault_b"]
    ma, mb = v["token_mint_a"], v["token_mint_b"]
    ba = (acc.get(va) or {}).get("amount", 0)
    bb = (acc.get(vb) or {}).get("amount", 0)
    da, db = decs.get(ma, 0), decs.get(mb, 0)
    # positions
    pos_rows = []
    wpk = v["clp"]
    w = wp.get(wpk)
    for p in v["positions"]:
        if p["position_key"] == "11111111111111111111111111111111":
            continue
        pe = acc.get(p["position_key"]) or {}
        L = pe.get("liquidity", 0)
        tl, tu = pe.get("tick_lower"), pe.get("tick_upper")
        if not w or w.get("sqrt_price") is None:
            pos_rows.append({"pos": p["position_key"], "err": "no whirlpool"})
            continue
        amt_a, amt_b = pos_amounts(L, tl, tu, w["tick_current"], w["sqrt_price"])
        pos_rows.append({"pos": p["position_key"], "L": L, "tl": tl, "tu": tu, "amt_a": amt_a, "amt_b": amt_b})
    tot_a = ba + sum(x.get("amt_a", 0) for x in pos_rows)
    tot_b = bb + sum(x.get("amt_b", 0) for x in pos_rows)
    pa = (prices.get(ma) or {}).get("price")
    pb = (prices.get(mb) or {}).get("price")
    usd_a = tot_a / 10 ** da * pa if pa else None
    usd_b = tot_b / 10 ** db * pb if pb else None
    usd = (usd_a or 0) + (usd_b or 0)
    if usd_a is None:
        unpriced.append({"vault": vk, "mint": ma, "amount": tot_a, "dec": da, "symbol": symbols.get(ma)})
    if usd_b is None:
        unpriced.append({"vault": vk, "mint": mb, "amount": tot_b, "dec": db, "symbol": symbols.get(mb)})
    total_usd += usd
    out["vaults"][vk] = {"mint_a": ma, "sym_a": symbols.get(ma), "dec_a": da, "bal_a": ba, "pos_amt_a": sum(x.get("amt_a", 0) for x in pos_rows),
                         "mint_b": mb, "sym_b": symbols.get(mb), "dec_b": db, "bal_b": bb, "pos_amt_b": sum(x.get("amt_b", 0) for x in pos_rows),
                         "usd_a": usd_a, "usd_b": usd_b, "usd": usd, "positions": pos_rows,
                         "lp_supply": (r2["lp_supply"].get(v["lp_mint"]) or {}).get("value", {}).get("uiAmountString")}
    print(f"{vk[:8]} {symbols.get(ma)} {ba/10**da:.4f}+pos{sum(x.get('amt_a',0) for x in pos_rows)/10**da:.4f} | "
          f"{symbols.get(mb)} {bb/10**db:.4f}+pos{sum(x.get('amt_b',0) for x in pos_rows)/10**db:.4f} | USD {usd:,.2f}")
out["total_usd"] = total_usd
out["unpriced"] = unpriced
json.dump(out, open(f"{A}/valuation.json", "w"), indent=1)
print(f"\nTOTAL USD (priced): {total_usd:,.2f}")
print("unpriced:", json.dumps(unpriced, indent=1))
