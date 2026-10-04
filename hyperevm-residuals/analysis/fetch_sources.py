#!/usr/bin/env python3
"""Fetch verified sources from Etherscan V2 for HyperEVM (chainid 999). Read-only."""
import json, os, re, sys, time, urllib.parse, urllib.request

ENV = "/home/heisenberg/CA/.env"
OUT = os.path.join(os.path.dirname(__file__))

def get_key():
    for line in open(ENV):
        m = re.match(r'^ETHERSCANV2_API_KEY=(.*)$', line.strip())
        if m:
            return m.group(1).strip().strip('"').strip("'")
    raise SystemExit("no key")

KEY = get_key()
BASE = "https://api.etherscan.io/v2/api"

def fetch(params):
    params = dict(params)
    params["apikey"] = KEY
    url = BASE + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read())
        except Exception as e:
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))

def getsource(addr):
    d = fetch({"chainid": 999, "module": "contract", "action": "getsourcecode", "address": addr})
    return d

def save(name, data):
    p = os.path.join(OUT, f"src_{name}.json")
    with open(p, "w") as f:
        json.dump(data, f, indent=1)
    return p

if __name__ == "__main__":
    addrs = sys.argv[1:]
    for a in addrs:
        if ":" in a:
            name, addr = a.split(":", 1)
        else:
            name, addr = a, a
        try:
            d = getsource(addr)
            r = (d.get("result") or [{}])
            r0 = r[0] if isinstance(r, list) and r else {}
            print(f"{name} {addr}: status={d.get('status')} msg={d.get('message')} name={r0.get('ContractName')} compiler={r0.get('CompilerVersion')} verified={bool(r0.get('SourceCode'))} proxy={r0.get('Proxy')}")
            save(name, d)
        except Exception as e:
            print(f"{name} {addr}: ERROR {e}")
