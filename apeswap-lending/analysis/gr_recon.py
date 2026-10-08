#!/usr/bin/env python3
"""GoldRush reconnaissance for ApeSwap Lending cTokens (read-only, local).
Usage: python3 gr_recon.py <mode> ...
  recent-tx <token> [pages]
  holders <token> [maxpages]
  asset-balances <address>
"""
import json, os, sys, time, urllib.parse, urllib.request

KEY = None
for line in open('/home/heisenberg/CA/.env'):
    if line.startswith('GOLD_RUSH_API_KEY='):
        KEY = line.strip().split('=', 1)[1]
BASE = 'https://api.covalenthq.com/v1'

def get(path, **params):
    params['key'] = KEY
    url = f"{BASE}/{path}/?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8.5.0'})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if d.get('error'):
                if 'being indexed' in str(d.get('error_message','')):
                    return {'items': [], 'pagination': {}, 'error_message': d.get('error_message')}
                raise RuntimeError(d.get('error_message'))
            return d.get('data') or {}
        except urllib.error.HTTPError as e:
            body = e.read()[:300]
            if attempt == 3:
                raise RuntimeError(f'HTTP {e.code}: {body}')
            time.sleep(2 * (attempt + 1))
        except Exception as e:
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))

def recent_tx(tok, pages=1):
    for p in range(pages):
        d = get(f'56/address/{tok}/transactions_v2', **{'page-size': 100, 'page-number': p})
        items = d.get('items', [])
        if not items:
            break
        for it in items:
            names = [ (l or {}).get('decoded', {}).get('name') if (l or {}).get('decoded') else None for l in (it.get('log_events') or []) ]
            rel = [n for n in names if n and ('Borrow' in n or 'Liquidat' in n or 'Redeem' in n or 'Mint' in n or 'Repay' in n)]
            if rel:
                print(f"blk={it['block_height']} {it['block_signed_at'][:10]} {it['tx_hash'][:18]} from={it['from_address'][:10]} {rel}")

def holders(tok, maxpages=20):
    out = []
    for p in range(maxpages):
        d = get(f'56/tokens/{tok}/token_holders', **{'page-size': 100, 'page-number': p})
        items = d.get('items', [])
        out += items
        if not (d.get('pagination') or {}).get('has_more'):
            break
        time.sleep(0.3)
    return out

def main():
    mode = sys.argv[1]
    if mode == 'recent-tx':
        recent_tx(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1)
    elif mode == 'holders':
        hs = holders(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 20)
        print(len(hs))
        for h in hs:
            print(h['address'], h['balance'])
    elif mode == 'asset-balances':
        d = get(f"56/address/{sys.argv[2]}/balances_v2", **{'nft': 'false'})
        for it in d.get('items', []):
            if int(it.get('balance', '0')) > 0:
                print(it['contract_address'], it['contract_ticker_symbol'], it['balance'], it.get('quote'))

if __name__ == '__main__':
    main()
