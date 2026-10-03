#!/usr/bin/env python3
"""Fetch verified sources from Etherscan V2 for facets. Saves raw JSON + extracted sources.
Usage: python3 fetch_sources.py <chainid> <chainname>"""
import json, os, sys, time, urllib.request, re

KEY = os.environ['ETHERSCANV2_API_KEY']
chainid, chain = sys.argv[1], sys.argv[2]
BASE = os.path.dirname(os.path.abspath(__file__))
raw_dir = os.path.join(BASE, 'sources', f'{chain}_raw')
src_dir = os.path.join(BASE, 'sources', chain)
os.makedirs(raw_dir, exist_ok=True)
os.makedirs(src_dir, exist_ok=True)

m = json.load(open(os.path.join(BASE, 'facets', 'all_facets.json')))
facets = list(m[chain]['facets'].keys())

def get(url):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print(f"  retry {attempt}: {e}", flush=True)
            time.sleep(2 + attempt * 2)
    raise RuntimeError("failed")

index = {}
for addr in facets:
    url = (f"https://api.etherscan.io/v2/api?chainid={chainid}&module=contract&action=getsourcecode"
           f"&address={addr}&apikey={KEY}")
    j = get(url)
    open(os.path.join(raw_dir, f'{addr}.json'), 'w').write(json.dumps(j, indent=1))
    res = (j.get('result') or [{}])[0]
    name = res.get('ContractName') or 'UNVERIFIED'
    src = res.get('SourceCode') or ''
    impl = res.get('Implementation') or ''
    entry = {'address': addr, 'name': name, 'compiler': res.get('CompilerVersion'),
             'optimization': res.get('OptimizationUsed'), 'impl': impl, 'verified': bool(src)}
    if src:
        # extract source files
        d = os.path.join(src_dir, f"{name}_{addr[:10]}")
        os.makedirs(d, exist_ok=True)
        if src.startswith('{{'):
            try:
                std = json.loads(src[1:-1])
                for path, f in std.get('sources', {}).items():
                    p = os.path.join(d, path)
                    os.makedirs(os.path.dirname(p), exist_ok=True)
                    content = f.get('content', '')
                    open(p, 'w').write(content)
                entry['files'] = list(std.get('sources', {}).keys())
                entry['settings'] = std.get('settings', {}).get('optimizer')
            except Exception as e:
                open(os.path.join(d, 'RAW.sol'), 'w').write(src)
                entry['parse_error'] = str(e)
        elif src.startswith('{'):
            try:
                std = json.loads(src)
                for path, f in std.get('sources', {}).items():
                    p = os.path.join(d, path)
                    os.makedirs(os.path.dirname(p), exist_ok=True)
                    open(p, 'w').write(f.get('content', ''))
                entry['files'] = list(std.get('sources', {}).keys())
            except Exception as e:
                open(os.path.join(d, 'RAW.sol'), 'w').write(src)
                entry['parse_error'] = str(e)
        else:
            open(os.path.join(d, f'{name}.sol'), 'w').write(src)
            entry['files'] = [f'{name}.sol']
    index[addr] = entry
    print(f"{chain} {addr} {name} verified={bool(src)} files={len(entry.get('files', []))}", flush=True)
    time.sleep(0.28)

json.dump(index, open(os.path.join(src_dir, '_index.json'), 'w'), indent=1)
print("DONE", chain, len(facets))
