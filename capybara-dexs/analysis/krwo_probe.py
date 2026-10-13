#!/usr/bin/env python3
"""Targeted probes: KRWO paths (pool 0x4b63ec62) with corrected KRWO price."""
import json
import sys
sys.path.insert(0, '.')
from quote_probe import enc, sig, call

W = 10 ** 18
POOL = "0x4b63ec6284810f62cecba6f03cf17413b0f4cec3"
USDT = "0x5c13e303a62fc5dedf5b52d66873f2e59fedadc2"
KRWO = "0x7fc692699f2216647a0e06225d8bdf8cdee40e7f"
WKLAY = "0x19aac5f612f524b754ca7e7c41cbfa2e981a4432"
P_KRWO = 1 / 1334.0          # market USD per KRWO (1 KRW)
P_USDT = 1.0
P_WK = 0.046635091365749844

st = json.load(open('live_state.json'))
assets = {a['underlying']: a for a in st['assets'] if a['pool'] == POOL}


def qswap(frm, to, amt_raw):
    r = call(enc(POOL, sig("quotePotentialSwap(address,address,int256)"), [frm, to, amt_raw]))
    if not isinstance(r, str) or not r.startswith("0x"):
        return None
    b = bytes.fromhex(r[2:])
    return int.from_bytes(b[0:32], "big"), int.from_bytes(b[32:64], "big")


def qdep(tok, amt_raw):
    r = call(enc(POOL, sig("quotePotentialDeposit(address,uint256)"), [tok, amt_raw]))
    return int(r, 16) if isinstance(r, str) and r.startswith("0x") else None


def qwdother(frm, to, liq):
    r = call(enc(POOL, sig("quotePotentialWithdrawFromOtherAsset(address,address,uint256)"), [frm, to, liq]))
    if not isinstance(r, str) or not r.startswith("0x"):
        return None
    b = bytes.fromhex(r[2:])
    return int.from_bytes(b[0:32], "big"), int.from_bytes(b[32:64], "big")


print("=== swap USDT -> KRWO (pool 0x4b63ec62); KRWO=$%.7f market, oracle=$0.000667 ===" % P_KRWO)
best = None
for amt_t in [10, 25, 50, 100, 200, 400, 600, 800, 1000, 1500, 2000, 3000]:
    amt = int(amt_t * 10 ** 6)
    q = qswap(USDT, KRWO, amt)
    if not q:
        print(f"  {amt_t:>6} USDT: revert")
        continue
    out = q[0] / 10 ** 6
    in_usd = amt_t * P_USDT
    out_usd = out * P_KRWO
    pr = out_usd - in_usd
    if best is None or pr > best[1]:
        best = (amt_t, pr, in_usd, out_usd)
    print(f"  {amt_t:>6} USDT -> {out:>14.2f} KRWO  in=${in_usd:>8.2f} out=${out_usd:>8.2f} profit=${pr:>7.2f}")
print("  BEST:", best)

print("=== deposit USDT -> withdrawFromOtherAsset KRWO ===")
best2 = None
for amt_t in [10, 25, 50, 100, 200, 400, 600, 800, 1000, 1500, 2000]:
    amt = int(amt_t * 10 ** 6)
    lp = qdep(USDT, amt)
    if not lp:
        continue
    q = qwdother(USDT, KRWO, lp)
    if not q:
        continue
    out = q[0] / 10 ** 6
    in_usd = amt_t * P_USDT
    out_usd = out * P_KRWO
    pr = out_usd - in_usd
    if best2 is None or pr > best2[1]:
        best2 = (amt_t, pr, in_usd, out_usd)
    print(f"  {amt_t:>6} USDT dep -> wd {out:>14.2f} KRWO  in=${in_usd:>8.2f} out=${out_usd:>8.2f} profit=${pr:>7.2f}")
print("  BEST:", best2)

print("=== swap KRWO -> USDT (reverse, for completeness) ===")
for amt_t in [100, 1000, 10000, 100000]:
    amt = int(amt_t * 10 ** 6)
    q = qswap(KRWO, USDT, amt)
    if not q:
        print(f"  {amt_t:>6} KRWO: revert")
        continue
    out = q[0] / 10 ** 6
    in_usd = amt_t * P_KRWO
    out_usd = out * P_USDT
    print(f"  {amt_t:>6} KRWO -> {out:>10.4f} USDT  in=${in_usd:>8.2f} out=${out_usd:>8.2f} profit=${out_usd - in_usd:>7.2f}")
