#!/usr/bin/env python3
"""C2-28 — bounded live balance check of the cork v2 managed cellars (Ethereum).

For each managed cellar ID (cork v2, Ethereum mainnet), fetch all token balances
via the keyless Blockscout v2 API and aggregate USD value. Read-only.

Usage: python3 cellar_balances.py <cellar_ids_json> <out_json>
"""
import json
import sys
import time
import urllib.request

UA = {"User-Agent": "zombie-hunt-ci/1.0 (read-only research)"}
BS = "https://eth.blockscout.com/api/v2"


def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())


def get_retry(url, attempts=3, pause=3):
    last = None
    for _ in range(attempts):
        try:
            return get(url)
        except Exception as e:
            last = e
            time.sleep(pause)
    raise last


def main():
    ids_path, out_path = sys.argv[1], sys.argv[2]
    ids = json.load(open(ids_path))["cellar_ids"]
    results = []
    total = 0.0
    for i, addr in enumerate(ids):
        row = {"address": addr, "tokens": [], "usd": 0.0, "error": None}
        try:
            d = get_retry(f"{BS}/addresses/{addr}/token-balances")
            for t in d if isinstance(d, list) else []:
                tok = t.get("token", {})
                dec = int(tok.get("decimals") or 0)
                raw = int(t.get("value") or 0)
                amt = raw / (10 ** dec) if dec else raw
                rate = t.get("exchange_rate")
                usd = (amt * float(rate)) if rate else None
                row["tokens"].append({
                    "symbol": tok.get("symbol"), "address": tok.get("address_hash"),
                    "amount": amt, "usd": usd,
                })
                if usd:
                    row["usd"] += usd
        except Exception as e:
            row["error"] = str(e)
        row["usd"] = round(row["usd"], 2)
        total += row["usd"]
        results.append(row)
        print(f"[{i+1}/{len(ids)}] {addr} ${row['usd']:.2f}"
              + (f" ERR {row['error']}" if row["error"] else ""))
        time.sleep(0.7)
    out = {"source": "eth.blockscout.com/api/v2 (keyless)",
           "cellar_count": len(ids), "total_usd": round(total, 2), "cellars": results}
    json.dump(out, open(out_path, "w"), indent=1)
    print(f"TOTAL ${total:.2f} across {len(ids)} managed cellars -> {out_path}")


if __name__ == "__main__":
    main()
