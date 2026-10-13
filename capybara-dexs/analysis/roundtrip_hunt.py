#!/usr/bin/env python3
"""Compose deployed quotes (deposit -> withdrawFromOtherAsset) to hunt for profitable round trips."""
import json
import sys
sys.path.insert(0, '.')
from quote_probe import enc, sig, call

st = json.load(open('live_state.json'))
pr = json.load(open('prices.json'))
W = 10 ** 18

fb = {
    '0xa9999999c3d05fb75ce7230e0d22f5625527d583': 0.046384410831635,
    '0xb0bb95ac3195a266ab924596ba32c2a10e245a95': 0.046384410831635,
    '0xd05fcb2d4c427232c3b36a33e21a4f23810a298f': 0.046384410831635,
    '0x7fc692699f2216647a0e06225d8bdf8cdee40e7f': 0.00072,
}


def price(u):
    if u in pr:
        return pr[u]['price']
    if u in fb:
        return fb[u]
    return 0.0


def qdep(pool, tok, amt):
    r = call(enc(pool, sig("quotePotentialDeposit(address,uint256)"), [tok, amt]))
    return int(r, 16) if isinstance(r, str) and r.startswith("0x") else None


def qwdother(pool, frm, to, liq):
    r = call(enc(pool, sig("quotePotentialWithdrawFromOtherAsset(address,address,uint256)"), [frm, to, liq]))
    if not isinstance(r, str) or not r.startswith("0x"):
        return None, None
    b = bytes.fromhex(r[2:])
    return int.from_bytes(b[0:32], "big"), int.from_bytes(b[32:64], "big")


# group assets per pool
pools = {}
for a in st['assets']:
    pools.setdefault(a['pool'], []).append(a)

print("Round trip: deposit X of FROM -> withdrawFromOtherAsset to TO; value ratio (out/in)")
best = []
for pool, assets in pools.items():
    if len(assets) < 2:
        continue
    for A in assets:
        for B in assets:
            if A is B:
                continue
            decA, decB = A['udec'], B['udec']
            for amt_tokens in (10, 100, 1000, 10000):
                amt = amt_tokens * 10 ** decA
                lp = qdep(pool, A['underlying'], amt)
                if not lp:
                    continue
                out, wd = qwdother(pool, A['underlying'], B['underlying'], lp)
                if out is None:
                    continue
                in_usd = amt_tokens * price(A['underlying'])
                out_usd = out / 10 ** decB * price(B['underlying'])
                ratio = out_usd / in_usd if in_usd > 0 else 0
                if ratio > 0.9:
                    best.append((ratio, pool, A['symbol'], A['underlying'], B['symbol'], B['underlying'], amt_tokens, lp, out, in_usd, out_usd))
best.sort(reverse=True)
for b in best[:25]:
    ratio, pool, asym, aaddr, bsym, baddr, amt_tokens, lp, out, in_usd, out_usd = b
    print(f"ratio={ratio:8.4f} pool={pool[:10]} {asym}->{bsym} in={amt_tokens} inUSD={in_usd:.2f} outUSD={out_usd:.2f} lp={lp/1e18:.3f}")
if not best:
    print("no candidates with ratio > 0.9")
