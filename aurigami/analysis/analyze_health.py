#!/usr/bin/env python3
"""Analyze health_scan.json: shortfall distribution."""
import json

d = json.load(open('/home/heisenberg/CA/aurigami/analysis/health_scan.json'))
short = {a: r['shortfall'] / 1e18 for a, r in d.items() if isinstance(r.get('shortfall'), int) and r['shortfall'] > 0}
liq = {a: r['liquidity'] / 1e18 for a, r in d.items() if isinstance(r.get('liquidity'), int) and r['liquidity'] > 0}
rev = [a for a, r in d.items() if 'revert' in r]
print('total scanned:', len(d))
print('with shortfall>0:', len(short), ' total USD shortfall:', round(sum(short.values()), 2))
print('with liquidity>0:', len(liq), ' total USD liquidity:', round(sum(liq.values()), 2))
print('reverts (bad oracle path):', len(rev))
print()
print('top 30 by shortfall USD:')
for a, s in sorted(short.items(), key=lambda kv: -kv[1])[:30]:
    print(f'  {a}  ${s:,.4f}')
print()
import collections
buckets = collections.Counter()
for s in short.values():
    if s < 0.01: buckets['<$0.01'] += 1
    elif s < 0.1: buckets['$0.01-0.1'] += 1
    elif s < 1: buckets['$0.1-1'] += 1
    elif s < 10: buckets['$1-10'] += 1
    elif s < 100: buckets['$10-100'] += 1
    elif s < 1000: buckets['$100-1k'] += 1
    else: buckets['>$1k'] += 1
print('shortfall buckets:', dict(buckets))
print()
print('top 10 by liquidity:')
for a, s in sorted(liq.items(), key=lambda kv: -kv[1])[:10]:
    print(f'  {a}  ${s:,.2f}')
