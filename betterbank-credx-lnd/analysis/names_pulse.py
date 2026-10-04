#!/usr/bin/env python3
"""Fetch contract names from PulseChain scan API for a list of addresses."""
import json, sys, time, urllib.request

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

addrs = [l.strip() for l in open(sys.argv[1]) if l.strip() and not l.startswith('#')]
out = {}
for i, a in enumerate(addrs):
    try:
        d = get(f"https://api.scan.pulsechain.com/api?module=contract&action=getsourcecode&address={a}")
        r = (d.get('result') or [{}])[0]
        name = r.get('ContractName') or '(unverified)'
        src = (r.get('SourceCode') or '')
        out[a] = {"name": name, "verified": bool(src), "proxy": r.get('Proxy'), "impl": r.get('Implementation')}
    except Exception as e:
        out[a] = {"error": str(e)}
    print(a, json.dumps(out[a]))
    time.sleep(0.15)
json.dump(out, open(sys.argv[2], 'w'), indent=1)
