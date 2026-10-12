#!/usr/bin/env python3
"""Analyze state-dump.json: excess (skim), pricing via DefiLlama, pair ranking."""
import json, os, urllib.request, sys

HERE = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(HERE, "state-dump.json")))
UA = {"User-Agent": "Mozilla/5.0 zombie-ci"}

# known token addresses on BSC
KNOWN = {
    "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c": ("WBNB", 18),
    "0x55d398326f99059ff775485246999027b3197955": ("USDT", 18),
    "0xe9e7cea3dedca5984780bafc599bd69add087d56": ("BUSD", 18),
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d": ("USDC", 18),
    "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3": ("DAI", 18),
    "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c": ("BTCB", 18),
    "0x2170ed0880ac9a755fd29b2688956bd959f933f8": ("ETH", 18),
    "0x0eb3a705fc54725037cc9e008bdede697f62f335": ("ATOM", 18),
    "0x56b6fb708fc5732dec1afc8d8556423a2edccbd6": ("EOS", 18),
    "0xf8a0bf9cf54bb92f17374d9e9a321e6a111a51bd": ("LINK", 18),
    "0xba2ae424d960c26247dd6c32edc70b295c744c43": ("DOGE", 8),
    "0x4338665cbb7b2485a8855a139b75d5e34ab0db94": ("LTC", 18),
    "0x7083609fce4d1d8dc0c979aab8c869ea2c873402": ("DOT", 18),
    "0x4b0f1812e5df2a09796481ff14017e6005508003": ("TWT", 18),
    "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82": ("CAKE", 18),
    "0x3d6545b08693dae087e957cb1180ee38b9e3c25e": ("ETC", 18),
    "0xc9849e6fdb743d08faee3e34dd2d1bc69ea11a51": ("BUNNY", 18),
    "0x5f0da599bb2cccfcf6fdfd7d81743b6020864350": ("MBT?" , 18),
}

def llama_prices(addrs):
    out = {}
    B = 40
    for i in range(0, len(addrs), B):
        chunk = addrs[i:i+B]
        url = "https://coins.llama.fi/prices/current/" + ",".join("bsc:" + a for a in chunk)
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=25) as r:
                j = json.loads(r.read())
            for k, v in j.get("coins", {}).items():
                out[k.split(":", 1)[1].lower()] = v["price"]
        except Exception as e:
            print("llama fail", str(e)[:100], file=sys.stderr)
    return out

tok = d["tokens"]
prices = llama_prices(list(tok.keys()))
print("llama prices:", {t[:10]: round(p,6) for t,p in prices.items()})

rows = []
for p, v in d["pairs"].items():
    t0, t1 = v["token0"], v["token1"]
    r0, r1 = v["reserve0"] or 0, v["reserve1"] or 0
    b0, b1 = v.get("bal0") or 0, v.get("bal1") or 0
    d0 = (tok.get(t0) or {}).get("decimals") or 18
    d1 = (tok.get(t1) or {}).get("decimals") or 18
    a0, a1 = r0 / 10**d0, r1 / 10**d1
    bb0, bb1 = b0 / 10**d0, b1 / 10**d1
    p0, p1 = prices.get(t0), prices.get(t1)
    usd0 = a0 * p0 if p0 else 0
    usd1 = a1 * p1 if p1 else 0
    exc0 = max(0.0, bb0 - a0); exc1 = max(0.0, bb1 - a1)
    exusd = (exc0 * p0 if p0 else 0) + (exc1 * p1 if p1 else 0)
    rows.append({
        "pair": p, "token0": t0, "token1": t1,
        "sym0": (tok.get(t0) or {}).get("symbol"), "sym1": (tok.get(t1) or {}).get("symbol"),
        "res0": a0, "res1": a1, "bal0": bb0, "bal1": bb1,
        "usd0": usd0, "usd1": usd1, "usd": usd0 + usd1, "excess_usd": exusd,
        "lp_supply": v["totalSupply"] or 0, "kLast": v["kLast"],
        "price0": (a1 / a0) if a0 else None,
    })
rows.sort(key=lambda r: -r["usd"])
tot = sum(r["usd"] for r in rows)
tot_excess = sum(r["excess_usd"] for r in rows)
print(f"\ntotal priced USD (llama-listed tokens): {tot:,.2f}")
print(f"total excess (balance-reserve) USD: {tot_excess:,.2f}")
print("\nTOP 20 PAIRS:")
for r in rows[:20]:
    print(f"  {r['pair']} {r['sym0']}/{r['sym1']} usd={r['usd']:,.2f} "
          f"res=({r['res0']:.6g},{r['res1']:.6g}) bal=({r['bal0']:.6g},{r['bal1']:.6g}) "
          f"excess=${r['excess_usd']:,.2f} lp={r['lp_supply']:.6g}")

json.dump(rows, open(os.path.join(HERE, "pairs-analysis.json"), "w"), indent=1)
print("\nwrote pairs-analysis.json")
