#!/usr/bin/env python3
"""Analyze state.json: cover economics — collateral vs covToken supplies vs claim status."""
import json, os

d = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')))
block = d['block']
DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'

prot_by_addr = {p['protocol']: p for p in d['protocols']}

rows = []
tot = {}
for cv in d['covers']:
    p = prot_by_addr[cv['protocol']]
    col = cv['collateral']
    bal = cv['collateralBalance'] or 0
    cs = cv['claimSupply'] or 0
    ns = cv['noclaimSupply'] or 0
    if bal == 0 and cs == 0 and ns == 0:
        continue
    # claim for this cover's round (if any)
    claim = None
    if p['claimNonce'] > cv['claimNonce']:
        idx = cv['claimNonce']
        if idx < len(p['claims']):
            claim = p['claims'][idx]
    tot[col] = tot.get(col, 0) + bal
    rows.append({
        'cover': cv['cover'], 'name': cv['name'], 'protocol': p['name'], 'proto': cv['protocol'],
        'collateral': col, 'bal': bal, 'claimSupply': cs, 'noclaimSupply': ns,
        'expired': cv['expirationTimestamp'], 'coverNonce': cv['claimNonce'], 'protoNonce': p['claimNonce'],
        'claim': claim, 'proxyAdmin': cv['proxyAdmin'], 'proxyImpl': cv['proxyImpl'],
        'claimHeldByCover': cv['claimHeldByCover'], 'noclaimHeldByCover': cv['noclaimHeldByCover'],
    })

print(f"block {block}, {len(rows)} covers with nonzero state")
print()
hdr = f"{'name':42s} {'col':6s} {'balance':>22s} {'CLAIMsup':>22s} {'NOCLAIMsup':>22s} {'claim%':>8s} {'exp':>12s}"
print(hdr)
for r in sorted(rows, key=lambda x: -x['bal']):
    c = r['claim']
    cstr = f"{c['payoutNumerator']}/{c['payoutDenominator']}" if c else ('-' if r['protoNonce'] == r['coverNonce'] else 'MISSING')
    colname = 'DAI' if r['collateral'] == DAI else r['collateral'][:10]
    print(f"{r['name']:42s} {colname:6s} {r['bal']/1e18:>22.6f} {r['claimSupply']/1e18:>22.6f} {r['noclaimSupply']/1e18:>22.6f} {cstr:>8s} {r['expired']:>12d}")

print()
print("TOTALS by collateral:")
for k, v in tot.items():
    print(f"  {k}: {v/1e18:.6f}")

# proxy admin variety
admins = {}
for cv in d['covers']:
    admins.setdefault(cv['proxyAdmin'], 0)
    admins[cv['proxyAdmin']] += 1
print()
print("proxy admin distribution:", admins)
impls = {}
for cv in d['covers']:
    impls.setdefault(cv['proxyImpl'], 0)
    impls[cv['proxyImpl']] += 1
print("proxy impl distribution:", impls)

# protocol proxy admins
padm = {}
for p in d['protocols']:
    padm.setdefault(p['proxyAdmin'], 0)
    padm[p['proxyAdmin']] += 1
print("protocol proxy admin distribution:", padm)

# cover-level accounting deltas
print()
print("Accounting checks (bal vs supplies):")
for r in rows:
    diff_c = r['bal'] - r['claimSupply']
    diff_n = r['bal'] - r['noclaimSupply']
    if diff_c != 0 or diff_n != 0:
        print(f"  {r['name']:42s} bal={r['bal']/1e18:.6f} clsup={r['claimSupply']/1e18:.6f} nlsup={r['noclaimSupply']/1e18:.6f} dC={diff_c/1e18:.6f} dN={diff_n/1e18:.6f}")

# claims details
print()
for p in d['protocols']:
    if p['claims']:
        print(f"protocol {p['name']} nonce={p['claimNonce']} claims={json.dumps(p['claims'])}")
