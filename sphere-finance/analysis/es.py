#!/usr/bin/env python3
"""Etherscan V2 helper for Polygon (chainid=137). Read-only."""
import json, os, sys, time, urllib.parse, urllib.request

API = "https://api.etherscan.io/v2/api"
KEY = os.environ["ETHERSCANV2_API_KEY"]

def call(params, chainid=137, retries=3):
    p = {"chainid": chainid, "apikey": KEY, **params}
    url = API + "?" + urllib.parse.urlencode(p)
    for i in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                d = json.load(r)
            if d.get("status") == "0" and "rate limit" in str(d.get("result", "")).lower():
                time.sleep(2); continue
            return d
        except Exception as e:
            if i == retries - 1: raise
            time.sleep(2)
    return d

def txlist(address, startblock=0, endblock=99999999, page=1, offset=100, sort="asc", chainid=137):
    return call({"module": "account", "action": "txlist", "address": address,
                 "startblock": startblock, "endblock": endblock, "page": page,
                 "offset": offset, "sort": sort}, chainid)

def getcreation(txhash, chainid=137):
    return call({"module": "contract", "action": "getcontractcreation",
                 "contractaddresses": txhash}, chainid)

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "txlist":
        d = txlist(sys.argv[2], page=int(sys.argv[3]) if len(sys.argv) > 3 else 1)
        print(json.dumps(d))
