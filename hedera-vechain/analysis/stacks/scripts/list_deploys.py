#!/usr/bin/env python3
"""Enumerate smart-contract deploys by a principal via Hiro API (threaded)."""
import json, urllib.request, time, os
from concurrent.futures import ThreadPoolExecutor

PRINCIPAL = "SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR"
BASE = f"https://api.hiro.so/extended/v1/address/{PRINCIPAL}/transactions?limit=50&offset="

def get(off):
    req = urllib.request.Request(BASE + str(off), headers={"User-Agent": "research-readonly"})
    for attempt in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=60).read())
        except Exception as e:
            if attempt == 3: raise
            time.sleep(1.5)

def main():
    first = get(0)
    total = first["total"]
    pages = list(range(0, total, 50))
    deploys = []
    types = {}
    with ThreadPoolExecutor(max_workers=6) as ex:
        for d in ex.map(get, pages):
            for r in d["results"]:
                types[r["tx_type"]] = types.get(r["tx_type"], 0) + 1
                if r["tx_type"] == "smart_contract":
                    sc = r.get("smart_contract") or {}
                    deploys.append({"name": sc.get("contract_id"), "height": r["block_height"], "tx": r["tx_id"]})
    print("total txs", total, "types:", types)
    print("deploys:", len(deploys))
    for x in sorted(deploys, key=lambda y: y["height"] or 0):
        print(x["height"], x["name"])
    here = os.path.dirname(os.path.abspath(__file__))
    json.dump(deploys, open(os.path.join(here, "..", "evidence", "deploys.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
