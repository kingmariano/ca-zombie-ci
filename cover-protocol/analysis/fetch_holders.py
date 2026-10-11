#!/usr/bin/env python3
"""Fetch token holders for all cover covTokens via GoldRush API.
Output: analysis/holders.json  (address -> balance per token)
"""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV['GOLD_RUSH_API_KEY']

def holders(token, page_size=1000):
    out = []
    page = 0
    while True:
        url = f'https://api.covalenthq.com/v1/eth-mainnet/tokens/{token}/token_holders_v2/?page-size={page_size}&page-number={page}'
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {KEY}', 'User-Agent': 'Mozilla/5.0'})
        for attempt in range(3):
            try:
                r = json.loads(urllib.request.urlopen(req, timeout=60).read())
                break
            except Exception as e:
                if attempt == 2:
                    return {'error': str(e)}
                time.sleep(2 * (attempt + 1))
        if r.get('error'):
            return {'error': r.get('error_message') or str(r['error'])}
        items = r['data']['items']
        out.extend(items)
        if not r['data']['pagination'].get('has_more'):
            break
        page += 1
        if page > 50:
            break
    return {'holders': out, 'pages': page + 1}

if __name__ == '__main__':
    d = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')))
    result = {'block': d['block'], 'tokens': {}}
    for cv in d['covers']:
        for kind, tok in (('noclaim', cv['noclaimCovToken']), ('claim', cv['claimCovToken'])):
            if tok in result['tokens']:
                continue
            # only fetch tokens with supply > 0
            sup = cv['noclaimSupply'] if kind == 'noclaim' else cv['claimSupply']
            if not sup:
                continue
            h = holders(tok)
            result['tokens'][tok] = {'kind': kind, 'cover': cv['cover'], 'name': cv['name'], 'supply': sup, **h}
            n = len(h.get('holders', []))
            err = h.get('error')
            print(f"{cv['name'][:40]:40s} {kind:7s} {tok} holders={n} {'ERR:'+str(err)[:60] if err else ''}", flush=True)
            time.sleep(0.2)
    json.dump(result, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holders.json'), 'w'), indent=1)
    print('saved holders.json')
