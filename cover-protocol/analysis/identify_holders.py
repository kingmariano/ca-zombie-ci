#!/usr/bin/env python3
"""Identify non-BPool contract holders of covTokens + top BPT holders."""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV['ETHERSCANV2_API_KEY']

hc = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holders_classified.json')))
state = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')))

seen = {}
for tok, rec in hc['tokens'].items():
    for h in rec['holderList']:
        if h['isContract'] and h['codeLen'] not in (22537, 23):
            seen.setdefault(h['addr'], {'codeLen': h['codeLen'], 'where': []})
            seen[h['addr']]['where'].append(f"{rec['coverName']}/{rec['kind']}")

def es(addr):
    url = f'https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address={addr}&apikey={KEY}'
    try:
        r = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30).read())
        if r.get('status') == '1' and r.get('result'):
            x = r['result'][0]
            return x.get('ContractName') or '(unverified)'
        return '(unverified)'
    except Exception as e:
        return f'err {e}'

print('== non-BPool contract holders ==')
for a, info in sorted(seen.items(), key=lambda x: -x[1]['codeLen']):
    print(f"{a} codeLen={info['codeLen']} name={es(a)}")
    print(f"    at: {', '.join(info['where'][:6])}")

# top BPT holders (from previous run) - identify them
print()
print('== top BPT holder addresses ==')
for a in ['0x8fc8551dd5e2dc5d2b04f2957e543d7d53a79f1e', '0xe0b94a7bb45dd905c79bb1992c9879f40f1caed5',
          '0x2f80e5163a7a774038753593010173322ea6f9fe', '0xdd79dc5b781b14ff091686961adc5d47e434f4b0']:
    print(a, '->', es(a))
    time.sleep(0.3)
