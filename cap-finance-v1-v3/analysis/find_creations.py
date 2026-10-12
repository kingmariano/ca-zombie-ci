#!/usr/bin/env python3
"""Find all contracts created by the 4 Cap deployer EOAs (GoldRush transactions)."""
import json, os, urllib.request, time

key = os.environ["GOLD_RUSH_API_KEY"]
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")

DEPLOYERS = {
    "v1": "0xAD364Da879C7AaFb519d5eaf07441D79BAcAbbbb",
    "v2": "0x59eE12714dFCFC300344f0256A4308c1C48E56ED",
    "v3": "0xDd5ee4e1a7fE06e0C30078292C94D889380d6d55",
    "v4": "0x764E7f8798D8193bEd69030AE66eb304968C3F93",
}

all_creations = {}
for label, addr in DEPLOYERS.items():
    found = []
    page = 0
    while page < 10:
        url = (f"https://api.covalenthq.com/v1/42161/address/{addr}/transactions_v2/"
               f"?key={key}&page-size=100&page-number={page}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        items = (d.get("data") or {}).get("items") or []
        if not items:
            break
        for it in items:
            if it.get("to_address") is None and it.get("successful"):
                found.append({"tx": it["tx_hash"], "block": it["block_height"],
                              "ts": it["block_signed_at"][:19]})
        page += 1
        time.sleep(0.3)
    all_creations[label] = found
    print(f"{label} {addr}: {len(found)} creations")
    for f in found:
        print("   ", f)

json.dump(all_creations, open(os.path.join(outdir, "deployer-creations.json"), "w"), indent=1)
