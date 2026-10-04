#!/usr/bin/env python3
"""Paginate MilkyWay staking contract batches + unstake requests."""
import base64, json, urllib.request, urllib.parse, sys, time

LCD = "https://osmosis-api.polkachu.com"
CONTRACT = "osmo1f5vfcph2dvfeqcqkhetwv75fda69z7e5c2dldm3kvgj23crkv6wqcn47a0"

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-research/1.0"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)

def smart(msg, contract=CONTRACT):
    q = base64.b64encode(json.dumps(msg).encode()).decode()
    return get(f"{LCD}/cosmwasm/wasm/v1/contract/{contract}/smart/{q}")

def all_batches():
    batches = []
    start = None
    while True:
        msg = {"batches": {"limit": 30}}
        if start is not None:
            msg["batches"]["start_after"] = start
        d = smart(msg)
        bs = d["data"]["batches"]
        if not bs:
            break
        batches.extend(bs)
        start = bs[-1]["id"]
        if len(batches) > 400:
            break
    return batches

if __name__ == "__main__":
    bs = all_batches()
    print(json.dumps(bs, indent=1))
    print("count:", len(bs), file=sys.stderr)
