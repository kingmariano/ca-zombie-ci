#!/usr/bin/env python3
"""Fetch logs from Etherscan V2 (chain 999) — read-only."""
import json, os, re, sys, time, urllib.parse, urllib.request

ENV = "/home/heisenberg/CA/.env"
def get_key():
    for line in open(ENV):
        m = re.match(r'^ETHERSCANV2_API_KEY=(.*)$', line.strip())
        if m:
            return m.group(1).strip().strip('"').strip("'")
    raise SystemExit("no key")
KEY = get_key()

def fetch(params):
    params = dict(params); params["apikey"] = KEY
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read())
        except Exception:
            if attempt == 3: raise
            time.sleep(2 * (attempt + 1))

def get_logs(address, topic0, from_block=0, to_block=99999999, page=1, offset=100):
    d = fetch({"chainid": 999, "module": "logs", "action": "getLogs", "address": address,
               "topic0": topic0, "fromBlock": from_block, "toBlock": to_block,
               "page": page, "offset": offset})
    return d

if __name__ == "__main__":
    addr = sys.argv[1]; topic0 = sys.argv[2]
    d = get_logs(addr, topic0)
    print("status", d.get("status"), "msg", d.get("message"), "n", len(d.get("result") or []) if isinstance(d.get("result"), list) else d.get("result"))
    if isinstance(d.get("result"), list):
        for r in d["result"][:10]:
            print(json.dumps(r))
    else:
        print(json.dumps(d)[:500])
