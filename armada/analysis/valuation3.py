#!/usr/bin/env python3
"""Valuation v3 — corrected Orca layouts:
   whirlpool: disc@0, config@8, tickSpacing@41, feeRate@45, liquidity@49(u128), sqrt@65(u128), tick@81(i32),
              mintA@101, vaultA@133, mintB@181, vaultB@213
   position:  disc@0, whirlpool@8, position_mint@40, liquidity@72(u128), tl@88(i32), tu@92(i32),
              fee_growth_a@96, fee_owed_a@112, fee_growth_b@120, fee_owed_b@136
"""
import base64, json, math, sys, time
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
import requests

A = "/home/heisenberg/CA/armada/analysis"
r1 = json.load(open(f"{A}/recon1.json"))
r2 = json.load(open(f"{A}/recon2.json"))
vaults = r1["vaults"]
Q64 = 1 << 64

clps = sorted({v["clp"] for v in vaults.values()})
res = get_accounts(clps, encoding="base64")
wp = {}
for k, a in zip(clps, res):
    raw = base64.b64decode(a["data"][0])
    assert len(raw) == 653, (k, len(raw))
    wp[k] = {"owner": a["owner"],
             "tick_spacing": int.from_bytes(raw[41:43], "little"),
             "fee_rate": int.from_bytes(raw[45:47], "little"),
             "liquidity": int.from_bytes(raw[49:65], "little"),
             "sqrt_price": int.from_bytes(raw[65:81], "little"),
             "tick_current": int.from_bytes(raw[81:85], "little", signed=True),
             "mint_a": b58encode(raw[101:133]), "vault_a": b58encode(raw[133:165]),
             "mint_b": b58encode(raw[181:213]), "vault_b": b58encode(raw[213:245])}

poskeys = []
for v in vaults.values():
    for p in v["positions"]:
        if p["position_key"] != "11111111111111111111111111111111":
            poskeys.append(p["position_key"])
uk = sorted(set(poskeys))
res = get_accounts(uk, encoding="base64")
pos = {}
for k, a in zip(uk, res):
    raw = base64.b64decode(a["data"][0])
    pos[k] = {"whirlpool": b58encode(raw[8:40]), "position_mint": b58encode(raw[40:72]),
              "liquidity": int.from_bytes(raw[72:88], "little"),
              "tick_lower": int.from_bytes(raw[88:92], "little", signed=True),
              "tick_upper": int.from_bytes(raw[92:96], "little", signed=True),
              "fee_owed_a": int.from_bytes(raw[112:120], "little"),
              "fee_owed_b": int.from_bytes(raw[136:144], "little")}

def sqrt_tick(t):  # real sqrt price (not Q64) at tick
    return 1.0001 ** (t / 2.0)

def pos_amounts(L, tl, tu, sqrtP_q64):
    P = sqrtP_q64 / Q64
    pa = sqrt_tick(tl); pb = sqrt_tick(tu)
    if L == 0:
        return 0, 0
    if P <= pa:
        return int(L * (pb - pa) / (pa * pb)), 0
    if P >= pb:
        return 0, int(L * (pb - pa))
    return int(L * (pb - P) / (P * pb)), int(L * (P - pa))

mints = sorted({v["token_mint_a"] for v in vaults.values()} | {v["token_mint_b"] for v in vaults.values()})
def llama_prices(ms):
    out = {}
    for i in range(0, len(ms), 50):
        q = ",".join(f"solana:{m}" for m in ms[i:i+50])
        for _ in range(3):
            try:
                r = requests.get(f"https://coins.llama.fi/prices/current/{q}", timeout=30)
                for k, v in (r.json().get("coins") or {}).items():
                    out[k.split(":", 1)[1]] = v
                break
            except Exception:
                time.sleep(2)
    return out
prices = llama_prices(mints)
symbols = {m: (prices.get(m) or {}).get("symbol") for m in mints}
for m in mints:
    if m not in prices:
        try:
            j = requests.get(f"https://api.dexscreener.com/latest/dex/tokens/{m}", timeout=25).json()
            pairs = j.get("pairs") or []
            if pairs:
                symbols[m] = pairs[0].get("baseToken", {}).get("symbol")
                if pairs[0].get("priceUsd"):
                    prices[m] = {"price": float(pairs[0]["priceUsd"]), "symbol": symbols[m], "source": "dexscreener"}
        except Exception:
            pass
        time.sleep(0.25)

r3 = json.load(open(f"{A}/recon3_mints.json"))
decs = {m: v["decimals"] for m, v in r3["pair_mints"].items() if v and "decimals" in v}

out = {"vaults": {}, "prices": prices, "symbols": symbols, "whirlpools": wp}
total_usd = 0.0
unpriced = []
for vk, v in vaults.items():
    ma, mb = v["token_mint_a"], v["token_mint_b"]
    ta = spl_token_amount(v["token_vault_a"]); tb = spl_token_amount(v["token_vault_b"])
    ba, bb = (ta or {}).get("amount", 0), (tb or {}).get("amount", 0)
    da, db = decs.get(ma, 0), decs.get(mb, 0)
    w = wp[v["clp"]]
    pos_rows = []
    for p in v["positions"]:
        pk = p["position_key"]
        if pk == "11111111111111111111111111111111":
            continue
        pe = pos.get(pk)
        if not pe:
            pos_rows.append({"pos": pk, "err": "missing"}); continue
        amt_a, amt_b = pos_amounts(pe["liquidity"], pe["tick_lower"], pe["tick_upper"], w["sqrt_price"])
        pos_rows.append({"pos": pk, "L": pe["liquidity"], "tl": pe["tick_lower"], "tu": pe["tick_upper"],
                         "amt_a": amt_a, "amt_b": amt_b, "fee_a": pe["fee_owed_a"], "fee_b": pe["fee_owed_b"],
                         "whirlpool_ok": pe["whirlpool"] == v["clp"]})
    pos_a = sum(x.get("amt_a", 0) for x in pos_rows); pos_b = sum(x.get("amt_b", 0) for x in pos_rows)
    tot_a, tot_b = ba + pos_a, bb + pos_b
    pa = (prices.get(ma) or {}).get("price"); pb = (prices.get(mb) or {}).get("price")
    usd_a = tot_a / 10 ** da * pa if pa else None
    usd_b = tot_b / 10 ** db * pb if pb else None
    usd = (usd_a or 0) + (usd_b or 0)
    if usd_a is None: unpriced.append({"vault": vk, "mint": ma, "amount": tot_a, "dec": da, "sym": symbols.get(ma)})
    if usd_b is None: unpriced.append({"vault": vk, "mint": mb, "amount": tot_b, "dec": db, "sym": symbols.get(mb)})
    total_usd += usd
    out["vaults"][vk] = {"mint_a": ma, "sym_a": symbols.get(ma), "dec_a": da, "bal_a": ba, "pos_amt_a": pos_a,
                         "mint_b": mb, "sym_b": symbols.get(mb), "dec_b": db, "bal_b": bb, "pos_amt_b": pos_b,
                         "usd_a": usd_a, "usd_b": usd_b, "usd": usd, "positions": pos_rows,
                         "lp_supply": (r2["lp_supply"].get(v["lp_mint"]) or {}).get("value", {}).get("uiAmountString"),
                         "withdrawal_fee": v["withdrawal_fee"], "performance_fee": v["performance_fee"],
                         "pool_liquidity": w["liquidity"], "pool_tick": w["tick_current"]}
    print(f"{vk[:8]} {symbols.get(ma)} {ba/10**da:.4f}+{pos_a/10**da:.6f} | {symbols.get(mb)} {bb/10**db:.4f}+{pos_b/10**db:.6f} | USD {usd:,.2f}")
out["total_usd"] = total_usd
out["unpriced"] = unpriced
json.dump(out, open(f"{A}/valuation3.json", "w"), indent=1)
print(f"\nTOTAL USD: {total_usd:,.2f}")
print("unpriced:", json.dumps(unpriced))
print("positions with L>0:", sum(1 for d in out['vaults'].values() for p in d['positions'] if p.get('L', 0) > 0))
