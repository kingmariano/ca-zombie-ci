#!/usr/bin/env python3
"""Enumerate token balances for all candidate Sphere addresses via GoldRush."""
import json, os, sys, time, urllib.request

KEY = None
for line in open("/home/heisenberg/CA/.env"):
    if line.startswith("GOLD_RUSH_API_KEY="):
        KEY = line.split("=", 1)[1].strip().strip('"').strip("'")

def balances(addr, chain=137, retries=4):
    url = f"https://api.covalenthq.com/v1/{chain}/address/{addr}/balances_v2/?key={KEY}&no-spam=true"
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if d.get("error"):
                if "rate" in str(d).lower() or d.get("error_code") == 429:
                    time.sleep(2 * (i + 1)); continue
                return {"error": d}
            return d["data"]
        except Exception as e:
            if i == retries - 1:
                return {"error": str(e)}
            time.sleep(2 * (i + 1))

if __name__ == "__main__":
    targets = json.load(open(sys.argv[1]))  # {name: address}
    out = {}
    for name, addr in targets.items():
        d = balances(addr)
        if "error" in d:
            print(name, addr, "ERR", str(d["error"])[:80], flush=True)
            out[name] = {"address": addr, "error": str(d["error"])[:200]}
        else:
            items = [i for i in d["items"] if int(i["balance"]) > 0]
            out[name] = {"address": addr, "items": [
                {"symbol": i["contract_ticker_symbol"], "addr": i["contract_address"],
                 "balance": i["balance"], "decimals": i["contract_decimals"],
                 "quote": i.get("quote")} for i in items]}
            nz = [i for i in items if i.get("quote")]
            print(name, addr, "items:", len(items), "priced:", [(i["contract_ticker_symbol"], i.get("quote")) for i in nz][:8], flush=True)
        time.sleep(0.35)
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    print("DONE")
