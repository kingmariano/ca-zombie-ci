#!/usr/bin/env python3
"""Fetch all holders of ApeSwap Lending oTokens via GoldRush; save JSON."""
import json, sys, time, urllib.parse, urllib.request

KEY = None
for line in open('/home/heisenberg/CA/.env'):
    if line.startswith('GOLD_RUSH_API_KEY='):
        KEY = line.strip().split('=', 1)[1]

TOKENS = {
 'oBANANA':'0xC2E840BdD02B4a1d970C87A912D8576a7e61D314',
 'oETH':'0xaA1b1E1f251610aE10E4D553b05C662e60992EEd',
 'oBUSD':'0x0096B6B49D13b347033438c4a699df3Afd9d2f96',
 'oUSDT':'0xdBFd516D42743CA3f1C555311F7846095D85F6Fd',
 'oCake':'0x3353f5bcfD7E4b146F2eD8F1e8D875733Cd754a7',
 'oUSDC':'0x91B66a9Ef4f4CAD7F8AF942855C37Dd53520f151',
 'oBNB':'0x34878F6a484005AA90E7188a546Ea9E52b538F6f',
 'oBTCB':'0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA',
 'oDOT':'0x92D106c39aC068EB113B3Ecb3273B23Cd19e6e26',
 'oBNBx':'0x3EE2bd8C244B5B3656673c2A49447e41D31F8E1e',
}

def get(path, **params):
    params['key'] = KEY
    url = f"https://api.covalenthq.com/v1/{path}/?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8.5.0'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if d.get('error'):
                raise RuntimeError(d.get('error_message'))
            return d.get('data') or {}
        except Exception:
            if attempt == 4:
                raise
            time.sleep(3 * (attempt + 1))

allh = {}
for sym, addr in TOKENS.items():
    holders = []
    for p in range(10):
        d = get(f'56/tokens/{addr}/token_holders', **{'page-size': 1000, 'page-number': p})
        items = d.get('items', [])
        holders += [{'address': i['address'], 'balance': i['balance']} for i in items]
        if not (d.get('pagination') or {}).get('has_more'):
            break
        time.sleep(0.5)
    # drop zero balances
    nz = [h for h in holders if int(h['balance']) > 0]
    allh[sym] = nz
    print(f"{sym}: {len(holders)} entries, {len(nz)} nonzero", flush=True)
    time.sleep(0.5)
json.dump(allh, open('/home/heisenberg/CA/apeswap-lending/analysis/holders_raw.json', 'w'), indent=1)
uniq = sorted({h['address'].lower() for hs in allh.values() for h in hs})
print('unique holders:', len(uniq))
json.dump(uniq, open('/home/heisenberg/CA/apeswap-lending/analysis/holders_unique.json', 'w'), indent=1)
