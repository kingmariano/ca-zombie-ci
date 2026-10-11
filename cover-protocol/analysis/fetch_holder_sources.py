#!/usr/bin/env python3
"""Fetch sources for the value-holding non-pool contracts."""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV['ETHERSCANV2_API_KEY']
OUT = '/tmp/opencode/holder_contracts'
os.makedirs(OUT, exist_ok=True)

TARGETS = {
    'BonusRewards': '0x8fc8551dd5e2dc5d2b04f2957e543d7d53a79f1e',
    'Blacksmith': '0xe0b94a7bb45dd905c79bb1992c9879f40f1caed5',
    'c_63242a4e': '0x63242a4ea82847b20e506b63b0e2e2eff0cc6cb0',
    'c_00000f91': '0x00000f91109c4d0007e90000d9facad5298a0cac',
    'c_c7f877d8': '0xc7f877d838cf16d4f10a19564edba719792e80be',
    'c_0eae044f': '0x0eae044f00b0af300500f090ea00027097d03000',
    'c_2f80e516': '0x2f80e5163a7a774038753593010173322ea6f9fe',
    'c_b4b50bfa': '0xb4b50bfa4c4c90dd25a4cbe695f8124d24ac6474',
    'c_140022b7': '0x140022b7000081000001094700609300d2187dab',
    'c_60e1a571': '0x60e1a5714ab98f4ba55811c45899fb425433bb65',
    'c_0000007f': '0x0000000000007f150bd6f54c40a34d7c3d5e9f56',
}

summary = {}
for label, addr in TARGETS.items():
    url = f'https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode&address={addr}&apikey={KEY}'
    try:
        r = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30).read())
        x = r['result'][0]
        name = x.get('ContractName') or '(unverified)'
        raw = (x.get('SourceCode') or '').strip()
        fn = f'{OUT}/{label}.sol'
        if raw.startswith('{{'):
            try:
                src = json.loads(raw[1:-1])
                for sn, so in src['sources'].items():
                    open(f'{OUT}/{label}__{sn.replace("/","_")}', 'w').write(so['content'])
                summary[label] = {'addr': addr, 'name': name, 'multi': list(src['sources'].keys())}
            except Exception as e:
                summary[label] = {'addr': addr, 'name': name, 'err': str(e), 'raw_len': len(raw)}
        else:
            open(fn, 'w').write(raw)
            summary[label] = {'addr': addr, 'name': name, 'src_len': len(raw)}
        print(label, addr, '->', name, summary[label].get('multi') or summary[label].get('src_len'))
    except Exception as e:
        summary[label] = {'addr': addr, 'err': str(e)}
        print(label, addr, 'ERR', e)
    time.sleep(0.3)

json.dump(summary, open('/tmp/opencode/holder_contracts_summary.json', 'w'), indent=1)
