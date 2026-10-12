#!/usr/bin/env python3
"""Final valuation + E-U/H-O/P/S accounting for Narwhalswap (uses state-dump.json)."""
import json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(HERE, "state-dump.json")))
UA = {"User-Agent": "Mozilla/5.0 zombie-ci"}

WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
NAR = "0xa1303e6199b319a891b79685f0537d289af1fc83"
BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
USDT = "0x55d398326f99059ff775485246999027b3197955"
BTCB = "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c"

def llama(addrs):
    out = {}
    ids = ",".join("bsc:" + a for a in addrs)
    try:
        with urllib.request.urlopen(urllib.request.Request(
                "https://coins.llama.fi/prices/current/" + ids, headers=UA), timeout=25) as r:
            for k, v in json.loads(r.read()).get("coins", {}).items():
                out[k.split(":", 1)[1].lower()] = v["price"]
    except Exception as e:
        print("llama err", e, file=sys.stderr)
    return out

prices = llama([WBNB, BUSD, USDT, BTCB, NAR])
print("prices:", prices)

tok = d["tokens"]
def dec(t): return (tok.get(t) or {}).get("decimals") or 18
def sym(t): return (tok.get(t) or {}).get("symbol")
def usd(t, amt):
    p = prices.get(t)
    return amt * p if p else None

# pool-implied NAR price (WBNB per NAR) from the Narwhal NAR/WBNB pair
narw = d["pairs"]["0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2"]
nar_price_wbnb = (narw["reserve1"] / 10**18) / (narw["reserve0"] / 10**18)
nar_price_usd = nar_price_wbnb * prices.get(WBNB, 748.63)
print(f"NAR pool-implied price: {nar_price_wbnb:.6e} WBNB = ${nar_price_usd:.6f}")

# LP ownership classes for the top pairs (from verified holder reads; see holders/holders.md & ecosystem/)
LP_CLASSES = {
    "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2": {  # NAR/WBNB, LP supply 25,004.55
        "P": {"NLPLock 0x07f1b50d (team, unlockTime 2020-11-11)": 20099.440290714567},
        "H-O": {"farm V2_narwbnb stakers": 2243.7922353441586,
                "farm V3_narwbnb stakers": 1291.9763938937701,
                "farm V1_narwbnb stakers": 297.15667376367014,
                "EOA 0x242fb607": 560.8958211045665},
    },
    "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957": {  # WBNB/THUGS, LP 273.568
        "H-O": {"EOA 0x4d710603 (93%, dormant)": 254.40320879609737,
                "EOA 0xe99140fc": 18.1010302,
                "contract 0xb752f0cb": 1.0586986675167036},
    },
    "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3": {  # WBNB/BUSD, LP 285.471
        "H-O": {"farm V1_wbnb_busd stakers (81%)": 231.5316003639712,
                "EOA 0xa9d5f138": 33.68,
                "farm V2_wbnb_busd stakers": 11.943790749266458},
    },
    "0x6658cd8591285775fd31d525fc2b0f3b1dde9b47": {  # BTCB/NAR, LP 44.358
        "H-O": {"farm V3_btcb_nar stakers (83%)": 36.8345},
    },
}

NAME = {
    "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2": "NAR/WBNB",
    "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957": "WBNB/THUGS",
    "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3": "WBNB/BUSD",
    "0x6658cd8591285775fd31d525fc2b0f3b1dde9b47": "BTCB/NAR",
}

res = {"block": d["block"], "nar_pool_price_usd": nar_price_usd, "pairs": {}, "farm_nar_pots": {}, "totals": {}}
for p, v in d["pairs"].items():
    t0, t1 = v["token0"], v["token1"]
    r0 = (v["reserve0"] or 0) / 10**dec(t0)
    r1 = (v["reserve1"] or 0) / 10**dec(t1)
    u0, u1 = usd(t0, r0), usd(t1, r1)
    if t0 == NAR: u0 = r0 * nar_price_usd
    if t1 == NAR: u1 = r1 * nar_price_usd
    entry = {"name": NAME.get(p, f"{sym(t0)}/{sym(t1)}"), "token0": t0, "token1": t1,
             "r0": r0, "r1": r1, "usd0": u0, "usd1": u1,
             "usd": (u0 or 0) + (u1 or 0), "lp_supply": (v["totalSupply"] or 0) / 10**18}
    res["pairs"][p] = entry

# farm NAR pots (from farm-family-state.json / live reads)
farms = json.load(open(os.path.join(HERE, "farm-family-state.json")))["farms"]
pots = {
    "V2_narwbnb": 204706.94740596955, "V2_wbnb_busd": 46039.7613084826,
    "V3_narwbnb": 19694.0, "V3_btcb_nar": 5176.73, "T_small2": 8113.73,
    "T_med2": 3769.51, "T_huge2": 73665.16, "DIV_v3_2": 1333817.1359508433,
    "SmartChef": 634.0,
}
for k, amt in pots.items():
    res["farm_nar_pots"][k] = {"nar": amt, "usd_at_pool_price": amt * nar_price_usd}

# totals: pair reserves (hard side = non-NAR), buckets
hard = 0.0
for p, e in res["pairs"].items():
    hard += (e["usd0"] or 0) + (e["usd1"] or 0)
res["totals"]["all_pairs_usd_at_llama_and_nar_pool_price"] = hard

# P bucket: locker share of NAR/WBNB
locker_lp = 20099.440290714567
lp_total = res["pairs"]["0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2"]["lp_supply"]
share = locker_lp / lp_total
p_wbnb = share * res["pairs"]["0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2"]["r1"] * prices[WBNB]
p_nar = share * res["pairs"]["0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2"]["r0"]
res["totals"]["P_NLPLock"] = {"share": share, "wbnb": share * res["pairs"]["0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2"]["r1"],
                              "wbnb_usd": p_wbnb, "nar": p_nar, "nar_usd_at_pool_price": p_nar * nar_price_usd}
res["totals"]["nar_pots_usd_at_pool_price"] = sum(v["usd_at_pool_price"] for v in res["farm_nar_pots"].values())

json.dump(res, open(os.path.join(HERE, "valuation.json"), "w"), indent=1)
print(json.dumps(res["totals"], indent=1))
print("pairs total USD:", round(hard, 2))
for p in ("0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2", "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
          "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3", "0x6658cd8591285775fd31d525fc2b0f3b1dde9b47"):
    e = res["pairs"][p]
    print(f"{e['name']}: r0={e['r0']:.6g} usd0={e['usd0']} r1={e['r1']:.6g} usd1={e['usd1']} total={e['usd']:.2f}")
print("wrote valuation.json")
