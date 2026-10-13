#!/usr/bin/env python3
"""Hunt with deployed deposit quotes + validated withdraw/swap model.

For each pool/pair/size:
  lp = deployed quotePotentialDeposit(fromToken, amount)   (on-chain truth)
  simulate actual withdrawFromOtherAsset(from, to, lp) with the validated model
  value ratio = out_value(to) / in_value(from)
Also: deposit -> withdraw same asset (actual path).
"""
import copy
import json
import sys
sys.path.insert(0, '.')
from quote_probe import enc, sig, call
from actual_path_hunt import Pool, load, price

st = json.load(open('live_state.json'))
pools = load()


def qdep(pool, tok, amt):
    r = call(enc(pool, sig("quotePotentialDeposit(address,uint256)"), [tok, amt]))
    return int(r, 16) if isinstance(r, str) and r.startswith("0x") else None


def main():
    print("=== deployed-deposit -> actual withdrawFromOtherAsset ===")
    results = []
    for addr, p in pools.items():
        if len(p.assets) < 2:
            continue
        for ta, A in p.assets.items():
            for tb, B in p.assets.items():
                if ta == tb:
                    continue
                for amt_tokens in (1, 10, 100, 1000, 10000):
                    amt = amt_tokens * 10 ** A['dec']
                    lp = qdep(addr, ta, amt)
                    if not lp:
                        continue
                    p2 = copy.deepcopy(p)
                    try:
                        # apply deposit state change with the model (LP from deployed quote;
                        # liabilityToMint approximated as lp * liab / ts)
                        asset = p2.assets[ta]
                        l2m = lp * asset['liab'] // asset['ts']
                        asset['cash'] += amt * 10 ** (18 - A['dec'])
                        asset['liab'] += l2m
                        asset['ts'] += lp
                        out, withdrew = p2.withdraw_other(ta, tb, lp)
                    except Exception:
                        continue
                    in_usd = amt_tokens * A['price']
                    out_usd = out / 1e18 * B['price']
                    if in_usd > 0:
                        results.append((out_usd / in_usd, addr, A['sym'], B['sym'], amt_tokens, in_usd, out_usd))
    results.sort(reverse=True)
    for r in results[:25]:
        print(f"  ratio={r[0]:7.4f} {r[1][:10]} {r[2]}->{r[3]} amt={r[4]:>6} in=${r[5]:>9.2f} out=${r[6]:>9.2f}")
    if not results:
        print("  none")

    print("=== deployed-deposit -> actual withdraw same asset ===")
    res2 = []
    for addr, p in pools.items():
        for ta, A in p.assets.items():
            for amt_tokens in (1, 10, 100, 1000, 10000):
                amt = amt_tokens * 10 ** A['dec']
                lp = qdep(addr, ta, amt)
                if not lp:
                    continue
                p2 = copy.deepcopy(p)
                try:
                    asset = p2.assets[ta]
                    l2m = lp * asset['liab'] // asset['ts']
                    asset['cash'] += amt * 10 ** (18 - A['dec'])
                    asset['liab'] += l2m
                    asset['ts'] += lp
                    out = p2.withdraw(ta, lp)
                except Exception:
                    continue
                in_usd = amt_tokens * A['price']
                out_usd = out / 1e18 * A['price']
                if in_usd > 0:
                    res2.append((out_usd / in_usd, addr, A['sym'], amt_tokens, in_usd, out_usd))
    res2.sort(reverse=True)
    for r in res2[:15]:
        print(f"  ratio={r[0]:7.4f} {r[1][:10]} {r[2]} amt={r[3]:>6} in=${r[4]:>9.2f} out=${r[5]:>9.2f}")


if __name__ == "__main__":
    main()
