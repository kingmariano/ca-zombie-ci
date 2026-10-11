#!/usr/bin/env python3
"""Classify covToken holders: contract vs EOA, nonce, and compute H-O/S split.
Output: analysis/holders_classified.json
"""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')

def rpc_batch(calls, retries=4):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(RPC, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
                resp = json.loads(urllib.request.urlopen(req, timeout=90).read())
                byid = {r['id']: r for r in resp}
                out.extend([byid[j].get('result') for j in range(len(chunk))])
                break
            except Exception:
                if attempt == retries - 1:
                    raise
                time.sleep(2 * (attempt + 1))
    return out

d = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holders.json')))
state = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')))
block = state['block']

# collect all holder addresses
addrs = set()
for tok, info in d['tokens'].items():
    for h in info.get('holders', []):
        addrs.add(h['address'].lower())
addrs = sorted(addrs)
print(f'{len(addrs)} unique holder addresses')

# code + nonce for each
res_code = rpc_batch([("eth_getCode", [a, hex(block)]) for a in addrs])
res_nonce = rpc_batch([("eth_getTransactionCount", [a, hex(block)]) for a in addrs])
meta = {}
for i, a in enumerate(addrs):
    code = res_code[i] or '0x'
    meta[a] = {'isContract': len(code) > 2, 'codeLen': max(0, (len(code) - 2) // 2), 'nonce': int(res_nonce[i], 16) if res_nonce[i] else 0}
    if meta[a]['isContract']:
        meta[a]['codeHash'] = code  # keep to identify later

# known addresses
KNOWN = {
    '0xedfc81bf63527337cd2193925f9c0cf2d537acca': 'Cover ProtocolFactory',
    '0x0000000000000000000000000000000000000000': 'zero address',
    '0x000000000000000000000000000000000000dead': 'burn address',
}
for cv in state['covers']:
    KNOWN[cv['cover']] = 'Cover: ' + cv['name']
    KNOWN[cv['protocol']] = 'Protocol: ' + cv['protocolName']

# compute per-token, per-holder redeemable value
DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'
out = {'block': block, 'tokens': {}, 'meta': {k: {kk: vv for kk, vv in v.items() if kk != 'codeHash'} for k, v in meta.items()}}
cover_by_tok = {}
for cv in state['covers']:
    cover_by_tok[cv['noclaimCovToken']] = (cv, 'noclaim')
    cover_by_tok[cv['claimCovToken']] = (cv, 'claim')

total_ho = 0.0
total_s = 0.0
detail = []
for tok, info in d['tokens'].items():
    cv, kind = cover_by_tok[tok]
    holders = info.get('holders', [])
    bal_sum = sum(int(h['balance']) for h in holders)
    supply = info['supply']
    # payout ratio for this token
    proto = next(p for p in state['protocols'] if p['protocol'] == cv['protocol'])
    claim = None
    if proto['claimNonce'] > cv['claimNonce'] and cv['claimNonce'] < len(proto['claims']):
        claim = proto['claims'][cv['claimNonce']]
    if kind == 'claim':
        ratio = (claim['payoutNumerator'] / claim['payoutDenominator']) if claim else 0.0
    else:
        if claim:
            if claim['incidentTimestamp'] > cv['expirationTimestamp']:
                ratio = 1.0
            else:
                ratio = 1 - claim['payoutNumerator'] / claim['payoutDenominator']
        else:
            ratio = 1.0
    rec = {'token': tok, 'cover': cv['cover'], 'coverName': cv['name'], 'kind': kind,
           'collateral': cv['collateral'], 'collateralBalance': cv['collateralBalance'], 'supply': supply,
           'ratio': ratio, 'holders': len(holders), 'holderBalanceSum': bal_sum,
           'balanceMismatch': supply - bal_sum}
    hlist = []
    for h in holders:
        a = h['address'].lower()
        bal = int(h['balance'])
        m = meta.get(a, {})
        hv = {'addr': a, 'bal': bal, 'isContract': m.get('isContract'), 'codeLen': m.get('codeLen'), 'nonce': m.get('nonce'), 'known': KNOWN.get(a)}
        hlist.append(hv)
    hlist.sort(key=lambda x: -x['bal'])
    rec['holderList'] = hlist
    out['tokens'][tok] = rec
    detail.append(rec)

json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holders_classified.json'), 'w'), indent=1)

# summary: top holders across everything
print('\n== top 40 holder positions by redeemable USD (DAI=1, yDAI@PPS later) ==')
allpos = []
for rec in detail:
    for h in rec['holderList']:
        allpos.append((rec, h))
allpos.sort(key=lambda x: -(x[1]['bal'] / 1e18) * x[0]['ratio'])
for rec, h in allpos[:40]:
    print(f"{h['bal']/1e18:>16.4f} {rec['kind']:7s} ratio={rec['ratio']:.2f} {rec['coverName'][:38]:38s} {h['addr']} {'C' if h['isContract'] else 'E'} nonce={h['nonce']} {h['known'] or ''}")

# aggregate by holder type
print()
print('== holders that are CONTRACTS (potential stuck/buyable) ==')
for rec in detail:
    for h in rec['holderList']:
        if h['isContract'] and h['bal'] > 0:
            print(f"{h['bal']/1e18:>16.4f} {rec['kind']:7s} {rec['coverName'][:40]:40s} {h['addr']} codeLen={h['codeLen']} {h['known'] or ''}")

# totals
tot_dai = 0.0
tot_ydai = 0.0
for rec in detail:
    v = sum(h['bal'] for h in rec['holderList']) / 1e18 * rec['ratio']
    if rec['collateral'] == DAI:
        tot_dai += v
    else:
        tot_ydai += v
print()
print(f'redeemable (in collateral units, before 0.1% fee): DAI {tot_dai:.4f}, yDAI {tot_ydai:.4f}')
print(f'total collateral held: DAI {sum(c["collateralBalance"] for c in state["covers"] if c["collateral"]==DAI)/1e18:.4f}, yDAI {sum(c["collateralBalance"] for c in state["covers"] if c["collateral"]!=DAI)/1e18:.4f}')
