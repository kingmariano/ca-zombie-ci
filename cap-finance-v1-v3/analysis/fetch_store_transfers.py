#!/usr/bin/env python3
"""Fetch all USDC transfers of the v3/v4 Store from GoldRush; compute balance timeline."""
import json, os, urllib.request, time

key = os.environ["GOLD_RUSH_API_KEY"]
STORE = "0xf16033d20ADDa47Dc99eA291D0F4C4FeF2fF47af"
USDC = "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8"
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")
os.makedirs(outdir, exist_ok=True)

allrows = []
page = 0
while page < 20:
    url = (f"https://api.covalenthq.com/v1/42161/address/{STORE}/transfers_v2/"
           f"?contract-address={USDC}&key={key}&page-size=100&page-number={page}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    d = json.load(urllib.request.urlopen(req, timeout=60))
    items = d["data"]["items"]
    if not items:
        break
    for it in items:
        for t in it.get("transfers", []):
            if t["contract_address"].lower() == USDC.lower():
                allrows.append({
                    "ts": it["block_signed_at"], "block": it["block_height"],
                    "tx": it["tx_hash"], "type": t["transfer_type"],
                    "from": t["from_address"], "to": t["to_address"],
                    "amount": int(t["delta"]) / 1e6,
                })
    page += 1
    time.sleep(0.3)

allrows.sort(key=lambda r: r["block"])
with open(os.path.join(outdir, "store-usdc-transfers.json"), "w") as f:
    json.dump(allrows, f, indent=1)

print("total USDC transfer legs:", len(allrows))
bal = 0.0
events = []
for r in allrows:
    bal += r["amount"] if r["type"] == "IN" else -r["amount"]
    events.append((r["ts"][:19], r["type"], r["from"][:10], r["to"][:10], r["amount"], bal))
print(f"{'time':19} {'dir':3} {'from':10} {'to':10} {'amount':>12} {'bal':>12}")
for e in events[:15]:
    print(f"{e[0]} {e[1]:3} {e[2]:10} {e[3]:10} {e[4]:12.2f} {e[5]:12.2f}")
print("...")
for e in events[-15:]:
    print(f"{e[0]} {e[1]:3} {e[2]:10} {e[3]:10} {e[4]:12.2f} {e[5]:12.2f}")
print("final balance per transfer history:", bal)
