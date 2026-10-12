#!/usr/bin/env python3
"""Definitive final snapshot: all 90 pairs read fresh at one block + latest price + custody split."""
import json, math, urllib.request
from prom import *

FACTORY = "0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9"
W = "0x04a21a38d5e275d6023b27504beb3095dc43b0c0"
U = "0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed"
FEETO = "0x55594e57f80b2decd63608a4f2802f8003633ad2"
BURN = "0x000000000000000000000000000000000000dead"
ZERO = "0x0000000000000000000000000000000000000000"

def price():
    req = urllib.request.Request("https://coins.llama.fi/prices/current/prom:0x04a21a38d5e275d6023b27504beb3095dc43b0c0",
                                 headers={"User-Agent": "Mozilla/5.0"})
    d = json.loads(urllib.request.urlopen(req, timeout=30).read())
    c = d["coins"]["prom:0x04a21a38d5e275d6023b27504beb3095dc43b0c0"]
    return c["price"], c["timestamp"]

def main():
    px, pts = price()
    blk = block_number()
    blk_hex = hex(blk)
    n = call_uint(FACTORY, "allPairsLength()", block=blk_hex)
    pairs = []
    for i in range(n):
        pairs.append(dec_addr(call(FACTORY, SEL["allPairs(uint256)"] + enc_uint(i), block=blk_hex)))
    lh = json.load(open("lp_holders.json"))
    cats = {}
    tot = {"wprom": 0.0, "usdt": 0.0, "usd": 0.0}
    main_split = {}
    fee_minted_usd = 0.0
    for p in pairs:
        t0 = dec_addr(call(p, SEL["token0()"], block=blk_hex))
        t1 = dec_addr(call(p, SEL["token1()"], block=blk_hex))
        r0, r1, _ = reserves(p, block=blk_hex)
        b0 = bal(t0, p, block=blk_hex); b1 = bal(t1, p, block=blk_hex)
        ts = call_uint(p, "totalSupply()", block=blk_hex)
        feeto_lp = call_uint(p, "balanceOf(address)", [FEETO], block=blk_hex)
        d0 = call_uint(t0, "decimals()", block=blk_hex) if r0 else 18
        d1 = call_uint(t1, "decimals()", block=blk_hex) if r1 else 18
        a0 = r0 / 10**d0; a1 = r1 / 10**d1
        w = a0 if t0 == W else (a1 if t1 == W else 0.0)
        u = a0 if t0 == U else (a1 if t1 == U else 0.0)
        usd = w * px + u
        tot["wprom"] += w; tot["usdt"] += u; tot["usd"] += usd
        excess = (b0 - r0, b1 - r1)
        if ts and usd > 0:
            fee_minted_usd += usd * feeto_lp / ts
        info = lh.get(p, {})
        holders = info.get("holders", [])
        top = holders[0] if holders else None
        if p == "0x1ddbf7113e3711ae9918f2dc14efb6b302b1e0d2":
            cat = "main-live"
            user_lp = call_uint(p, "balanceOf(address)", ["0x2bA8968C1AE5984f049F28085f50D7Df4aD1a01e"], block=blk_hex)
            main_split = {"total_usd": usd, "user_lp": user_lp, "ts": ts, "feeTo_lp": feeto_lp,
                          "user_usd": usd * user_lp / ts, "feeTo_usd": usd * feeto_lp / ts,
                          "others_usd": usd * (ts - user_lp - feeto_lp) / ts}
        elif top and top["addr"].lower() in (BURN, ZERO) and ts and top["value"] / ts > 0.9:
            cat = "burned-LP"
        elif top and top["is_contract"]:
            cat = "contract-held"
        else:
            cat = "EOA-held"
        c = cats.setdefault(cat, {"count": 0, "wprom": 0.0, "usdt": 0.0, "usd": 0.0})
        c["count"] += 1; c["wprom"] += w; c["usdt"] += u; c["usd"] += usd
    out = {"block": blk, "price_wprom": px, "price_ts": pts,
           "pairs": n, "totals": tot, "cats": cats, "main_split": main_split,
           "feeTo_minted_usd": fee_minted_usd}
    json.dump(out, open("final_snapshot.json", "w"), indent=1)
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
