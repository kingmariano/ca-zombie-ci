#!/usr/bin/env python3
"""Full enumeration of ALL mainnet Soroban contracts (stellar.expert index),
with checkpoints. Run in background; saves mainnet_contracts_all.json.
"""
import json
import os
import time
import urllib.request

API = "https://api.stellar.expert/explorer/public"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mainnet_contracts_all.json")
UA = "Mozilla/5.0 (X11; Linux x86_64) heliobond-readonly-research/1.0"


def get_json(url, retries=8):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 20 + 15 * i
                print(f"429 rate limit; sleeping {wait}s", flush=True)
                time.sleep(wait)
                continue
            if i == retries - 1:
                raise
            time.sleep(2.0 * (i + 1))
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(2.0 * (i + 1))


def main():
    records = []
    if os.path.exists(OUT):
        try:
            prev = json.load(open(OUT))
            records = prev.get("records", [])
            print("resumed with", len(records), "records", flush=True)
        except Exception:
            records = []
    seen = {r["contract"] for r in records}
    url = f"{API}/contract?limit=200&order=asc"
    if records:
        url = f"{API}/contract?limit=200&order=asc&cursor={records[-1]['contract']}"
    pages = 0
    while url and pages < 5000:
        d = get_json(url)
        emb = d.get("_embedded", {}).get("records", [])
        new = [r for r in emb if r["contract"] not in seen]
        records.extend(new)
        seen.update(r["contract"] for r in new)
        pages += 1
        nxt = (d.get("_links", {}).get("next") or {}).get("href")
        url = ("https://api.stellar.expert" + nxt) if nxt and nxt.startswith("/") else nxt
        if pages % 25 == 0:
            print(f"pages={pages} records={len(records)}", flush=True)
            json.dump({"updated": time.time(), "total": len(records), "records": records}, open(OUT, "w"))
        if not emb or not nxt:
            break
        time.sleep(0.05)
    json.dump({"updated": time.time(), "total": len(records), "records": records}, open(OUT, "w"))
    print(f"DONE total={len(records)} pages={pages}", flush=True)


if __name__ == "__main__":
    main()
