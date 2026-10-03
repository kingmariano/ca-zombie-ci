#!/usr/bin/env python3
"""Paginate Blockscout /api/v2/addresses/{a}/transactions and list contract creations. Read-only."""
import json, sys, time, urllib.request, urllib.parse

BASE = {
    'base': 'https://base.blockscout.com/api/v2',
    'arb': 'https://arbitrum.blockscout.com/api/v2',
    'mantle': 'https://explorer.mantle.xyz/api/v2',
    'blast': 'https://blast.blockscout.com/api/v2',
}

def get(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'research-readonly'})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            if i == tries - 1:
                raise
            time.sleep(2 + i * 2)

def main(chain, addr, maxpages=20, out=None):
    api = BASE[chain]
    url = f'{api}/addresses/{addr}/transactions?filter=from'
    creations = []
    alltx = []
    for page in range(maxpages):
        d = get(url)
        items = d.get('items', [])
        for it in items:
            cc = it.get('created_contract')
            rec = {
                'hash': it.get('hash'),
                'to': (it.get('to') or {}).get('hash'),
                'created': (cc or {}).get('hash'),
                'created_name': (cc or {}).get('name'),
                'method': it.get('method'),
                'block': it.get('block_number'),
            }
            alltx.append(rec)
            if cc:
                creations.append(rec)
        np = d.get('next_page_params')
        if not np:
            break
        url = f'{api}/addresses/{addr}/transactions?' + urllib.parse.urlencode(np)
        time.sleep(0.4)
    res = {'chain': chain, 'address': addr, 'n_tx': len(alltx), 'creations': creations, 'txs': alltx}
    if out:
        json.dump(res, open(out, 'w'), indent=1)
    for c in creations:
        print(f"CREATE {c['created']} name={c['created_name']} block={c['block']} tx={c['hash']}")
    print(f"-- scanned {len(alltx)} txs, {len(creations)} creations")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 20,
         sys.argv[4] if len(sys.argv) > 4 else None)
