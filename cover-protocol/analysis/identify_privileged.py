#!/usr/bin/env python3
"""Identify privileged contracts of Cover Protocol (source name, proxy status, roles)."""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV['ETHERSCANV2_API_KEY']

def es(params):
    url = 'https://api.etherscan.io/v2/api?chainid=1&' + '&'.join(f'{k}={v}' for k, v in params.items()) + f'&apikey={KEY}'
    for _ in range(3):
        try:
            return json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30).read())
        except Exception:
            time.sleep(2)
    return {'status': '0', 'result': 'fetch failed'}

TARGETS = {
    'factory_owner_and_cover_proxy_admin': '0x15957f0ca310d35b2e73fb5070ce44a5b0141ab1',
    'old_factory_owner_and_10_protocol_admins': '0xdd79dc5b781b14ff091686961adc5d47e434f4b0',
    'factory_governance': '0xc698645b5c5b662b52a5a5c092804f23e3f5b4c5',
    'claim_auditor': '0x7eba9c735f8c1fe0670be69edf61dbfbbb3c76e4',
    'factory_treasury': '0xe0632311772d362f49b5118c40d5251c44bc8b2e',
    'cm_treasury': '0x859eefc267671595d987d0f6589d7771d4877113',
    'claim_manager': '0xd33f2e0173fd0ae2a64b208a7bd16bcdc68bc862',
}

out = {}
for label, addr in TARGETS.items():
    r = es({'module': 'contract', 'action': 'getsourcecode', 'address': addr})
    rec = {'address': addr}
    if r.get('status') == '1' and r.get('result'):
        x = r['result'][0]
        rec['contractName'] = x.get('ContractName')
        rec['compiler'] = x.get('CompilerVersion')
        rec['proxy'] = x.get('Proxy')
        rec['impl'] = x.get('Implementation')
        rec['src_len'] = len(x.get('SourceCode') or '')
    else:
        rec['error'] = str(r.get('result'))[:200]
    out[label] = rec
    print(label, addr, json.dumps(rec))
    time.sleep(0.3)

json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'privileged_contracts.json'), 'w'), indent=1)
print('saved')
