#!/usr/bin/env python3
"""Summarize MetaESDT/NFT holdings for candidates + compute rough token USD where possible."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")
bal = json.load(open(os.path.join(RAW, "candidate_balances.json")))

print("=== NFT/MetaESDT positions by candidate (non-fungible balances) ===")
for addr, rec in bal.items():
    nfts = rec.get("nfts")
    if not isinstance(nfts, list) or not nfts:
        continue
    # group by collection
    from collections import defaultdict
    g = defaultdict(lambda: [0, 0, 0])  # count, total_balance, has_attrs
    for n in nfts:
        c = n.get("collection", "?")
        try:
            b = int(n.get("balance", "0"))
        except Exception:
            b = 0
        g[c][0] += 1
        g[c][1] += b
    parts = []
    for c, (cnt, tb, _) in sorted(g.items()):
        parts.append(f"{c} x{cnt} bal={tb}")
    print(f"{rec['name']:42s} [{','.join(parts)}]")

print()
print("=== fungible tokens with USD value > 1 (from /tokens) ===")
for addr, rec in bal.items():
    toks = rec.get("tokens")
    if not isinstance(toks, list):
        continue
    for t in toks:
        v = t.get("valueUsd")
        if v and v > 1:
            d = t.get("decimals", 18)
            print(f"{rec['name']:42s} {t['identifier']:22s} {int(t['balance'])/10**d:>22,.4f}  ${v:,.2f}  price={t.get('price')}")
