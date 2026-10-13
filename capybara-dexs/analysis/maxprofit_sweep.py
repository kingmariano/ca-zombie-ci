#!/usr/bin/env python3
"""Max-profit sweep: deposit(from) -> withdrawFromOtherAsset(to) per pool/pair/size.

Uses deployed deposit quote for LP minted (on-chain truth) and the validated model
for the withdraw+swap execution, including dynamic scale factors and cov-ratio fees.
"""
import copy
import json
import sys
sys.path.insert(0, '.')
from quote_probe import enc, sig, call
from actual_path_hunt import Pool, load

st = json.load(open('live_state.json'))
pools = load()
W = 10 ** 18


def qdep(pool, tok, amt):
    r = call(enc(pool, sig("quotePotentialDeposit(address,uint256)"), [tok, amt]))
    return int(r, 16) if isinstance(r, str) and r.startswith("0x") else None


def simulate(addr, p, ta, tb, amt_tokens):
    A = p.assets[ta]
    amt = int(amt_tokens * 10 ** A['dec'])
    lp = qdep(addr, ta, amt)
    if not lp:
        return None
    p2 = copy.deepcopy(p)
    a = p2.assets[ta]
    l2m = lp * a['liab'] // a['ts']
    a['cash'] += amt * 10 ** (18 - A['dec'])
    a['liab'] += l2m
    a['ts'] += lp
    try:
        out, withdrew = p2.withdraw_other(ta, tb, lp)
    except Exception as e:
        return None
    B = p.assets[tb]
    in_usd = amt_tokens * A['price']
    out_usd = out / 1e18 * B['price']
    return in_usd, out_usd


def main():
    results = []
    for addr, p in pools.items():
        for ta, A in p.assets.items():
            for tb, B in p.assets.items():
                if ta == tb:
                    continue
                best = None
                for amt_tokens in [0.01, 0.1, 1, 3, 10, 30, 100, 300, 1000, 3000, 10000, 30000, 100000, 300000]:
                    r = simulate(addr, p, ta, tb, amt_tokens)
                    if not r:
                        continue
                    in_usd, out_usd = r
                    profit = out_usd - in_usd
                    if in_usd > 0 and (best is None or profit > best[1]):
                        best = (amt_tokens, profit, in_usd, out_usd)
                if best and best[1] > 0.01:
                    results.append((best[1], addr, A['sym'], B['sym'], best))
    results.sort(reverse=True)
    print(f"{'max_profit_usd':>16}  pool        from->to                 best_amt   in_usd   out_usd")
    for profit, addr, asym, bsym, (amt, pr, iu, ou) in results:
        print(f"{profit:>16.2f}  {addr[:10]}  {asym:>12}->{bsym:<12} {amt:>9} {iu:>9.2f} {ou:>9.2f}")
    print("total (sum of per-path maxima, upper bound):", round(sum(r[0] for r in results), 2))


if __name__ == "__main__":
    main()
