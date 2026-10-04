#!/usr/bin/env python3
"""Enumerate ALL Soroban contracts on Stellar mainnet via stellar.expert's
public contract index, then identify candidates for the Heliobond vault:

  * created on/after 2026-06-01 (Heliobond org/repos created 2026-06-12)
  * WASM hash not shared with thousands of other contracts (dApp builds are rare)
  * WASM bytes contain Heliobond-specific markers ("Heliobond", "HBS",
    "QueuedClaim", "fund_project", ...)

Read-only. Saves raw pages to analysis/mainnet_contracts.json.
"""
import json
import os
import sys
import time
import urllib.request

API = "https://api.stellar.expert/explorer/public"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mainnet_contracts.json")
UA = "Mozilla/5.0 (X11; Linux x86_64) heliobond-readonly-research/1.0"


def get_json(url, retries=4):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            if i == retries - 1:
                raise
            time.sleep(1.5 * (i + 1))


def main():
    records = []
    url = f"{API}/contract?limit=200&order=desc"
    pages = 0
    cutoff = 1748736000  # 2026-06-01 UTC
    while url and pages < 2000:
        d = get_json(url)
        emb = d.get("_embedded", {}).get("records", [])
        records.extend(emb)
        pages += 1
        nxt = (d.get("_links", {}).get("next") or {}).get("href")
        url = ("https://api.stellar.expert" + nxt) if nxt and nxt.startswith("/") else nxt
        if pages % 10 == 0:
            print(f"pages={pages} records={len(records)}", flush=True)
        if not emb:
            break
        if emb and (emb[-1].get("created") or 0) < cutoff:
            print(f"reached pre-2026-06-01 records at page {pages}; stopping", flush=True)
            break
        time.sleep(0.12)
    print(f"TOTAL fetched: {len(records)} (pages={pages})")

    # distinct wasm hashes
    from collections import Counter
    wasm_counts = Counter(r.get("wasm") for r in records if r.get("wasm"))
    print(f"distinct wasm hashes: {len(wasm_counts)}")

    # Heliobond era
    era = [r for r in records if (r.get("created") or 0) >= cutoff]
    print(f"contracts created >= 2026-06-01: {len(era)}")
    era_wasm = Counter(r.get("wasm") for r in era if r.get("wasm"))
    print(f"distinct wasm hashes in era: {len(era_wasm)}")

    # contracts whose wasm is rare (<= 5 instances) in the fetched index
    rare_era = [r for r in era if r.get("wasm") and wasm_counts[r["wasm"]] <= 5]
    print(f"era contracts with rare wasm (<=5 instances in fetched set): {len(rare_era)}")

    with open(OUT, "w") as f:
        json.dump(
            {
                "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "total": len(records),
                "records": records,
                "era_rare_contracts": [r["contract"] for r in rare_era],
            },
            f,
        )
    print("wrote", OUT)

    # summary of rare-era wasm hashes
    rare_hashes = Counter(r["wasm"] for r in rare_era)
    print("rare era wasm hashes:", len(rare_hashes))
    for h, c in rare_hashes.most_common(50):
        print(f"  {h} x{c}")


if __name__ == "__main__":
    main()
