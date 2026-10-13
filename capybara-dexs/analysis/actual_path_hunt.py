#!/usr/bin/env python3
"""Exact simulation of the ACTUAL executable paths (deposit -> withdrawFromOtherAsset,
deposit -> withdraw, swap cycles) using the verified Wombat math model, with real
post-state updates, to find profitable extraction paths.

Uses the model validated against on-chain withdraw/swap quotes (deposit model is the
upstream formula; deployed deposit deviates slightly for some assets -> noted).
"""
import json
import sys
sys.path.insert(0, '.')
from wombat_math import (WAD, exact_deposit_to_equil, withdraw_from, swap_quote_func,
                         wmul, wdiv, quote_from_hcr, high_cov_ratio_fee)

st = json.load(open('live_state.json'))
pr = json.load(open('prices.json'))
fb = {}


def price(u):
    if u in pr:
        return pr[u]['price']
    return fb.get(u, 0.0)


class Pool:
    def __init__(self, p):
        self.addr = p['pool']
        self.amp = p['ampFactor']
        self.haircut = p['haircutRate']
        self.start_r = p['startCovRatio'] if 'startCovRatio' in p else 15 * 10**17
        self.end_r = p['endCovRatio'] if 'endCovRatio' in p else 18 * 10**17
        self.assets = {}  # token -> dict

    def add(self, a):
        self.assets[a['underlying']] = dict(
            sym=a['symbol'], dec=a['udec'], cash=a['cash'], liab=a['liability'],
            ts=a['totalSupply'], price=price(a['underlying']), P=a.get('relPriceInt', 10**18))

    # --- state-mutating ops (model) ---
    def deposit(self, token, amount_wad):
        a = self.assets[token]
        lp, l2m, rew = exact_deposit_to_equil(amount_wad, a['cash'], a['liab'], a['ts'], self.amp)
        if lp == 0:
            return 0
        a['cash'] += amount_wad
        a['liab'] += l2m
        a['ts'] += lp
        return lp

    def _withdraw_amount(self, token, liq):
        a = self.assets[token]
        amount, burn, fee = withdraw_from(liq, a['cash'], a['liab'], a['ts'], self.amp)
        return amount, burn

    def withdraw(self, token, liq):
        amount, burn = self._withdraw_amount(token, liq)
        a = self.assets[token]
        a['ts'] -= liq
        a['cash'] -= amount
        a['liab'] -= burn
        return amount

    def swap(self, frm, to, amount_wad):
        fa, ta = self.assets[frm], self.assets[to]
        sf = (fa['P'] * 10 ** 18) // ta['P']
        fc = (fa['cash'] * sf) // 10 ** 18
        fl = (fa['liab'] * sf) // 10 ** 18
        amt = (amount_wad * sf) // 10 ** 18
        from wombat_math import quote_from
        actual, haircut = quote_from(fc, fl, ta['cash'], ta['liab'], amt, self.amp, self.haircut)
        # high cov fee uses raw from values (HighCovRatioFeePoolV2._quoteFrom)
        final_r = wdiv(fa['cash'] + amount_wad, fa['liab'])
        if final_r > self.start_r:
            hf = wmul(high_cov_ratio_fee(wdiv(fa['cash'], fa['liab']), final_r, self.start_r, self.end_r), actual)
            actual -= hf
            haircut += hf
        fa['cash'] += amount_wad
        ta['cash'] -= (actual + haircut)
        return actual, haircut

    def withdraw_other(self, frm, to, liq):
        amount_w, burn = self._withdraw_amount(frm, liq)
        fa = self.assets[frm]
        fa['ts'] -= liq
        fa['cash'] -= amount_w
        fa['liab'] -= burn
        out, hc = self.swap(frm, to, amount_w)
        return out, amount_w


def load():
    pools = {}
    for a in st['assets']:
        pools.setdefault(a['pool'], []).append(a)
    out = {}
    for addr, assets in pools.items():
        pm = next(x for x in st['pools'] if x['pool'] == addr)
        p = Pool({'pool': addr, 'ampFactor': pm['ampFactor'],
                  'haircutRate': pm['haircutRate']})
        p.start_r = pm.get('startCovRatio') or 15*10**17
        p.end_r = pm.get('endCovRatio') or 18*10**17
        for a in assets:
            p.add(a)
        out[addr] = p
    return out


def main():
    pools = load()
    print("=== actual-path hunt: deposit A -> withdrawFromOtherAsset to B ===")
    results = []
    for addr, p in pools.items():
        if len(p.assets) < 2:
            continue
        for ta, A in p.assets.items():
            for tb, B in p.assets.items():
                if ta == tb:
                    continue
                for amt_tokens in (10, 100, 1000, 10000):
                    amt = amt_tokens * 10 ** A['dec']
                    # simulate on a fresh clone of the pool
                    import copy
                    p2 = copy.deepcopy(p)
                    try:
                        lp = p2.deposit(ta, amt)
                        if lp == 0:
                            continue
                        out, withdrew = p2.withdraw_other(ta, tb, lp)
                    except Exception:
                        continue
                    in_usd = amt_tokens * A['price']
                    out_usd = out / 10 ** B['dec'] * B['price']
                    if in_usd <= 0:
                        continue
                    results.append((out_usd / in_usd, addr, A['sym'], B['sym'], amt_tokens, in_usd, out_usd))
    results.sort(reverse=True)
    for r in results[:20]:
        print(f"  ratio={r[0]:7.4f} {r[1][:10]} {r[2]}->{r[3]} amt={r[4]} in=${r[5]:.2f} out=${r[6]:.2f}")
    if not results:
        print("  none")

    print("=== actual-path hunt: deposit A -> withdraw same A ===")
    res2 = []
    for addr, p in pools.items():
        for ta, A in p.assets.items():
            for amt_tokens in (100, 1000, 10000):
                amt = amt_tokens * 10 ** A['dec']
                import copy
                p2 = copy.deepcopy(p)
                try:
                    lp = p2.deposit(ta, amt)
                    if lp == 0:
                        continue
                    out = p2.withdraw(ta, lp)
                except Exception:
                    continue
                in_usd = amt_tokens * A['price']
                out_usd = out / 10 ** A['dec'] * A['price']
                if in_usd > 0:
                    res2.append((out_usd / in_usd, addr, A['sym'], amt_tokens, in_usd, out_usd))
    res2.sort(reverse=True)
    for r in res2[:10]:
        print(f"  ratio={r[0]:7.4f} {r[1][:10]} {r[2]} amt={r[3]} in=${r[4]:.2f} out=${r[5]:.2f}")
    if not res2:
        print("  none")

    print("=== actual-path hunt: 2-hop swap cycles within pool ===")
    res3 = []
    for addr, p in pools.items():
        toks = list(p.assets.keys())
        if len(toks) < 2:
            continue
        for ta in toks:
            for tb in toks:
                if ta == tb:
                    continue
                for amt_tokens in (100, 1000):
                    amt = amt_tokens * 10 ** p.assets[ta]['dec']
                    import copy
                    p2 = copy.deepcopy(p)
                    try:
                        mid, _ = p2.swap(ta, tb, amt)
                        if mid == 0:
                            continue
                        back, _ = p2.swap(tb, ta, mid)
                    except Exception:
                        continue
                    A, B = p.assets[ta], p.assets[tb]
                    in_usd = amt_tokens * A['price']
                    out_usd = back / 10 ** A['dec'] * A['price']
                    if in_usd > 0:
                        res3.append((out_usd / in_usd, addr, A['sym'], B['sym'], amt_tokens, in_usd, out_usd))
    res3.sort(reverse=True)
    for r in res3[:10]:
        print(f"  ratio={r[0]:7.4f} {r[1][:10]} {r[2]}->{r[3]}->back amt={r[4]} in=${r[5]:.2f} out=${r[6]:.2f}")
    if not res3:
        print("  none")


if __name__ == "__main__":
    main()
