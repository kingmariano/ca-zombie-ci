#!/usr/bin/env python3
"""Final cohort valuation at the frozen Moonriver head.

Outputs cohort_summary.json with the S / H-O / P / E-U split.
Read-only; prices from DefiLlama (coins.llama.fi) at run time.
"""
import json, urllib.request

def get(url, timeout=60):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=timeout))

# prices fetched 2026-10-10 (prices.json); re-fetch DAI/BUSD here
ids = ["coingecko:dai", "coingecko:binance-usd"]
extra = {}
try:
    r = get("https://coins.llama.fi/prices/current/" + ",".join(ids))
    extra = r.get("coins", {})
except Exception as e:
    extra = {"error": str(e)}

P = {
    "MOVR": 1.8066082739718927,
    "BTC": 82513.32584546937,
    "ETH": 2490.5563541325546,
    "USDC": 0.9997377559549633,
    "USDT": 0.9992303709694218,
    "DOT": 1.262010936123528,
    "KSM": 5.098100306129225,
    "FRAX": 0.9919730857261497,
    "MIM": 0.033007753733716394,
    "DAI": extra.get("coingecko:dai", {}).get("price", 1.0),
    "BUSD": extra.get("coingecko:binance-usd", {}).get("price", 1.0),
    "TOM": 0.0,  # no live market (dead chain); treated as $0
}

# ---- Huckleberry lending (cash = tokens held by markets at frozen head) ----
lend = json.load(open("huckleberry_lending.json"))
lend_rows = []
lend_cash_usd = 0.0
lend_net_usd = 0.0
for m in lend["markets"]:
    dec = m["underlying_decimals"] or 18
    cash = (m["getCash"] or 0) / 10 ** dec
    borr = (m["totalBorrows"] or 0) / 10 ** dec
    resv = (m["totalReserves"] or 0) / 10 ** dec
    sym = m["underlying_symbol"]
    px = P.get(sym, P.get({"MOVR(native)": "MOVR", "xcKSM": "KSM", "USDC.e": "USDC"}.get(sym, sym.replace(".m", "")), 0.0))
    cash_usd = cash * px
    net_usd = (cash + borr - resv) * px
    lend_cash_usd += cash_usd
    lend_net_usd += net_usd
    lend_rows.append({"market": m["market"], "symbol": m["symbol"], "underlying": sym,
                      "cash_tokens": round(cash, 8), "borrows_tokens": round(borr, 8),
                      "reserves_tokens": round(resv, 8), "price_usd": px,
                      "cash_usd": round(cash_usd, 2), "net_supplied_usd": round(net_usd, 2),
                      "oracle_price_raw": m["oracle_price_raw"]})

# ---- Moonswap / Huckleberry AMM stables ----
def stables(path, exclude=()):
    d = json.load(open(path))  # *_stables.json from aggregate_cohort.py
    rows = []
    total = 0.0
    for t, a in d["stable_tokens"].items():
        if t.lower() in [e.lower() for e in exclude]:
            continue
        sym = a["symbol"]
        px = P.get(sym, P.get({"USDC.e": "USDC"}.get(sym, sym.replace(".m", "")), 1.0))
        usd = a["human"] * px
        total += usd
        rows.append({"token": t, "symbol": sym, "decimals": a["decimals"],
                     "amount": round(a["human"], 6), "pairs": a["pair_count"],
                     "price_usd": px, "usd": round(usd, 2)})
    rows.sort(key=lambda r: -r["usd"])
    return d, rows, total

FAKE_DAI = "0xe7a534f34f6ba18a03e0e09ade4a9d6628aa69da"  # 9-dec scam/test "DAI", ~0 WMOVR side
ms_d, ms_rows, ms_total = stables("moonswap_stables.json", exclude=(FAKE_DAI,))
ha_d, ha_rows, ha_total = stables("huckleberry_amm_stables.json")

# WMOVR held in DEX pairs (not a stable; shown as extra context)
def wmovr_sum(path):
    d = json.load(open(path))
    s = 0
    for p in d["pairs"]:
        for side in ("0", "1"):
            if (p[f"symbol{side}"] or "").upper() == "WMOVR":
                s += (p[f"balance{side}"] or 0) / 10 ** (p[f"decimals{side}"] or 18)
    return s

ms_wmovr = wmovr_sum("moonswap_pairs.json")
ha_wmovr = wmovr_sum("huckleberry_amm_pairs.json")

out = {
    "head_block": 17381654,
    "head_utc": "2026-08-10T08:27:48Z",
    "prices": P,
    "huckleberry_lending": {
        "comptroller": "0xcffef313b69d83cb9ba35d9c0f882b027b846ddc",
        "oracle": "0xef502fb85311065aeb1ebe6b179400b03de2d9a5",
        "markets": lend_rows,
        "cash_usd_total": round(lend_cash_usd, 2),
        "net_supplied_usd_total": round(lend_net_usd, 2),
    },
    "moonswap": {
        "factory": "0x056973f631a5533470143bb7010c9229c19c04d2",
        "pair_count": ms_d["pair_count"],
        "stables": ms_rows,
        "stables_usd_total": round(ms_total, 2),
        "fake_dai_excluded": {"token": FAKE_DAI, "amount": 11339893.4184, "why": "9 decimals, 1e21 totalSupply, pair holds 0.0000025 WMOVR; not real DAI"},
        "wmovr_in_pairs": round(ms_wmovr, 4),
        "wmovr_usd": round(ms_wmovr * P["MOVR"], 2),
    },
    "huckleberry_amm": {
        "factory": "0x017603c8f29f7f6394737628a93c57ffba1b7256",
        "pair_count": ha_d["pair_count"],
        "stables": ha_rows,
        "stables_usd_total": round(ha_total, 2),
        "wmovr_in_pairs": round(ha_wmovr, 4),
        "wmovr_usd": round(ha_wmovr * P["MOVR"], 2),
    },
    "classification": {
        "E-U": 0.0, "H-O": 0.0, "P": 0.0,
        "S": round(ms_total + ha_total + lend_cash_usd, 2),
        "S_breakdown": {
            "moonswap_stables": round(ms_total, 2),
            "huckleberry_amm_stables": round(ha_total, 2),
            "huckleberry_lending_cash": round(lend_cash_usd, 2),
        },
    },
}
json.dump(out, open("cohort_summary.json", "w"), indent=2)
print(json.dumps(out["classification"], indent=2))
print("lending cash rows:")
for r in lend_rows:
    print(f"  {r['symbol']:<9} cash={r['cash_tokens']:>18,.6f} {r['underlying']:<8} px=${r['price_usd']:<12} = ${r['cash_usd']:>10,.2f}")
print("moonswap stables:")
for r in ms_rows:
    print(f"  {r['symbol']:<8} {r['amount']:>16,.4f} (${r['usd']:,.2f})")
print("huckleberry amm stables:")
for r in ha_rows:
    print(f"  {r['symbol']:<8} {r['amount']:>16,.4f} (${r['usd']:,.2f})")
print("DAI px:", P["DAI"], "BUSD px:", P["BUSD"])
