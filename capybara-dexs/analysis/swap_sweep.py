#!/usr/bin/env python3
"""Sweep all swap pairs in all pools: compare pool swap output value vs input value (USD)."""
import json
import sys
sys.path.insert(0, '.')
from quote_probe import enc, sig, call
from actual_path_hunt import load, price

st = json.load(open('live_state.json'))
pools = load()
W = 10 ** 18


def qswap(pool, frm, to, amt_raw):
    r = call(enc(pool, sig("quotePotentialSwap(address,address,int256)"), [frm, to, amt_raw]))
    if not isinstance(r, str) or not r.startswith("0x"):
        return None
    b = bytes.fromhex(r[2:])
    return int.from_bytes(b[0:32], "big"), int.from_bytes(b[32:64], "big")


def main():
    results = []
    for addr, p in pools.items():
        toks = list(p.assets.keys())
        for ta in toks:
            for tb in toks:
                if ta == tb:
                    continue
                A, B = p.assets[ta], p.assets[tb]
                best = None
                for amt_t in [0.001, 0.01, 0.1, 1, 3, 10, 30, 100, 300, 1000, 3000, 10000, 30000, 100000, 300000, 1000000]:
                    amt = int(amt_t * 10 ** A['dec'])
                    q = qswap(addr, ta, tb, amt)
                    if not q:
                        continue
                    out_raw = q[0]
                    out_t = out_raw / 10 ** B['dec']
                    in_usd = amt_t * A['price']
                    out_usd = out_t * B['price']
                    if in_usd <= 0:
                        continue
                    profit = out_usd - in_usd
                    if best is None or profit > best[1]:
                        best = (amt_t, profit, in_usd, out_usd)
                if best and best[1] > 0.05:
                    results.append((best[1], addr, A['sym'], B['sym'], best))
    results.sort(reverse=True)
    print(f"{'max_profit_usd':>16}  pool        from->to               best_amt   in_usd   out_usd")
    for profit, addr, asym, bsym, (amt, pr, iu, ou) in results:
        print(f"{profit:>16.2f}  {addr[:10]}  {asym:>12}->{bsym:<12} {amt:>9} {iu:>9.2f} {ou:>9.2f}")
    print("sum of per-path maxima (upper bound):", round(sum(r[0] for r in results), 2))


if __name__ == "__main__":
    main()
