#!/usr/bin/env python3
"""Compute the final Aequinox value split: S (gauge-frozen) vs H-O (non-gauge BPT).
Uses analysis/pools_classified.json + live gauge balances (read at the same pinned block).
Prices: DefiLlama 2026-10-11 (see analysis/prices.json)."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
px = {"USDT": 0.9990675934177985, "USDC": 0.9996715780762364, "BUSD": 0.998835953095354,
      "WBNB": 749.2985875216467, "WETH": 2520.32720908297, "BTCB": 82941.07840148671,
      "DAI": 0.9993843665605517, "TUSD": 0.998812217718787}
dec = {"0x55d398326f99059ff775485246999027b3197955": "USDT", "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d": "USDC",
       "0xe9e7cea3dedca5984780bafc599bd69add087d56": "BUSD", "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c": "WBNB",
       "0x2170ed0880ac9a755fd29b2688956bd959f933f8": "WETH", "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c": "BTCB",
       "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3": "DAI", "0x14016e85a25aeb13065688cafb43044c2ef86784": "TUSD"}

# gauge -> pool (from controller map + live reads)
gauge_pool = {  # keys normalised to lowercase below

    "0xaCC31d29022C8Eb2683597bF4c07De228Ed9EA07": "0xb3a07a9cef918b2ccec4bc85c6f2a7975c5e83f9",
    "0xDA9D57cAabBe48301d71b7eEaf546B4A206118d3": "0x9aa867870d5775a3c155325db0cb0b116bbf4b6a",
    "0x1dA7F4b2B9B644f307A313e304E1B061Eb605965": "0x74154c70f113c2b603aa49899371d05eeedd1e8c",
    "0x34EA84d3565824573073b1A63057baf57f842F02": "0x5ba2bc395b511ecf3f7c7f4f6c5de3c5586239ae",
    "0x00687547D75A2d1378984bE922e1450CcC89211E": "0x0256c70b89b3c0ed888b7b7d7767a701b2a67bea",
    "0xD105D7e65922e1ac725b799481c5c113cFfA2f0D": "0xe53896c872b39fa3254262d18157447504b211de",
    "0x9721189e8ac5DD0011EaB1Ee7c25B24624b75801": "0x276ab884805581b8e537c11e4906d545b295052f",
    "0xc328f8308B915D7DCD7D65d9c0e0a225abb3A95f": "0x835ff599b9388e4f733c165a15a93e736ebf91d3",
    "0x6d97daB82286D61225265232ea07FD50828F5F18": "0xe263e513395ee7d9b0228ad22824f1a860ff85cc",
}
# gauge BPT balances (live reads at block 127079392 / holder API)
gauge_bpt = {
    "0xaCC31d29022C8Eb2683597bF4c07De228Ed9EA07": 596884.604225989806715435,
    "0xDA9D57cAabBe48301d71b7eEaf546B4A206118d3": 15018.131113396024613359,
    "0x1dA7F4b2B9B644f307A313e304E1B061Eb605965": 32249.165941860671355406,
    "0x34EA84d3565824573073b1A63057baf57f842F02": 51.296624321011394760,
    "0x00687547D75A2d1378984bE922e1450CcC89211E": 2.117056709840423869,
    "0xD105D7e65922e1ac725b799481c5c113cFfA2f0D": 293457.625698938143457353,
    "0x9721189e8ac5DD0011EaB1eE7c25B24624b75801": 0.0,
    "0xc328f8308B915D7DCD7D65d9c0e0a225abb3A95f": 7593.544709374193874623,
    "0x6d97daB82286D61225265232ea07FD50828F5F18": 6.530345608219214963,
}

d = json.load(open(os.path.join(HERE, "pools_classified.json")))
pools = d["classified"]
by_addr = {p["pool"]: p for p in pools.values()}

def pool_usd(p):
    tot = 0.0
    for t, b in zip(p.get("tokens") or [], [int(x) for x in (p.get("balances") or [])]):
        sym = dec.get(t.lower())
        if sym:
            tot += (b / 1e18) * px[sym]
    return tot

total = 0.0
stuck = 0.0
ho = 0.0
rows = []
gauge_pool = {k.lower(): v.lower() for k, v in gauge_pool.items()}
gauge_bpt = {k.lower(): v for k, v in gauge_bpt.items()}
by_addr = {k.lower(): v for k, v in by_addr.items()}
for g, pool in gauge_pool.items():
    p = by_addr.get(pool)
    if not p:
        continue
    usd = pool_usd(p)
    supply = int(p.get("totalSupply") or 0) / 1e18
    gb = gauge_bpt[g]
    frac = gb / supply if supply else 0
    s = usd * frac
    h = usd * (1 - frac)
    total += usd
    stuck += s
    ho += h
    rows.append((pool, p["type"], usd, supply, gb, frac, s, h))

# pools without gauges (value-bearing)
gauged = set(gauge_pool.values())
for p in pools.values():
    if p["pool"] in gauged:
        continue
    usd = pool_usd(p)
    if usd > 0.01:
        total += usd
        ho += usd
        rows.append((p["pool"], p["type"], usd, int(p.get("totalSupply") or 0) / 1e18, 0, 0, 0, usd))

rows.sort(key=lambda r: -r[2])
out = {"prices": px, "rows": [
    {"pool": r[0], "type": r[1], "pool_usd": round(r[2], 2), "pool_bpt": r[3], "gauge_bpt": r[4],
     "gauge_frac": round(r[5], 6), "stuck_usd": round(r[6], 2), "holder_recoverable_usd": round(r[7], 2)}
    for r in rows], "total_pool_usd": round(total, 2), "stuck_usd": round(stuck, 2),
    "holder_recoverable_usd": round(ho, 2), "extractable_usd": 0.0}
json.dump(out, open(os.path.join(HERE, "final_values.json"), "w"), indent=1)
print(f"total pool USD   : ${total:,.2f}")
print(f"stuck (S)        : ${stuck:,.2f}")
print(f"holder-recover(HO): ${ho:,.2f}")
for r in rows[:14]:
    print(f"  ${r[2]:>10,.2f} {r[1]:16s} {r[0]} gauge_frac={r[5]:.4f} stuck=${r[6]:,.2f} HO=${r[7]:,.2f}")
