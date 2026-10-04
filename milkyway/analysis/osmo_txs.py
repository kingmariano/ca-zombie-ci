#!/usr/bin/env python3
"""Fetch MilkyWay Osmosis contract tx history via LCD tx search (query= syntax)."""
import json, urllib.request, urllib.parse, sys, time

LCD = "https://osmosis-api.polkachu.com"
CONTRACT = "osmo1f5vfcph2dvfeqcqkhetwv75fda69z7e5c2dldm3kvgj23crkv6wqcn47a0"

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def search(query, limit=100, page_key=None, order="ORDER_BY_DESC"):
    params = {"query": query, "pagination.limit": str(limit), "order_by": order}
    if page_key:
        params["pagination.key"] = page_key
    url = LCD + "/cosmos/tx/v1beta1/txs?" + urllib.parse.urlencode(params)
    return get(url)

def fetch_all(query, max_pages=50, limit=100, order="ORDER_BY_DESC"):
    out = []
    key = None
    for i in range(max_pages):
        d = search(query, limit=limit, page_key=key, order=order)
        out.extend(d.get("tx_responses", []))
        pg = d.get("pagination") or {}
        key = pg.get("next_key")
        total = pg.get("total")
        print(f"page {i}: +{len(d.get('tx_responses',[]))} total={total} next={'y' if key else 'n'}", file=sys.stderr)
        if not key:
            break
    return out

if __name__ == "__main__":
    query = f"wasm._contract_address='{CONTRACT}'"
    txs = fetch_all(query)
    print(json.dumps(txs), file=open("contract_txs.json", "w"))
    print("fetched:", len(txs), file=sys.stderr)
