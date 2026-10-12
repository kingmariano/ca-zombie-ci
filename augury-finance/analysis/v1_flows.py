#!/usr/bin/env python3
"""Pull all USDC transfers to/from the legacy divideds V1 (paginated)."""
import json, urllib.request, time, os
# key from env, never written to file
KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
UA = {"User-Agent": "Mozilla/5.0"}
V1 = "0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2"
USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

def get(url):
    req = urllib.request.Request(url, headers=UA)
    for a in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=40).read())
        except Exception as e:
            if a == 3: raise
            time.sleep(2)

txs = []
for page in range(1, 12):
    url = (f"https://api.etherscan.io/v2/api?chainid=137&module=account&action=tokentx"
           f"&contractaddress={USDC}&address={V1}&page={page}&offset=1000&sort=asc&apikey={KEY}")
    d = get(url)
    r = d.get("result", [])
    if not isinstance(r, list) or not r:
        print("page", page, "empty, status", d.get("status"), d.get("message"))
        break
    txs += r
    print("page", page, "got", len(r))
    if len(r) < 1000: break

inflow = outflow = 0
ins = []
outs = []
for t in txs:
    amt = int(t["value"]) / 1e6
    if t["to"].lower() == V1.lower():
        inflow += amt; ins.append((t["timeStamp"], amt, t["from"], t["hash"]))
    elif t["from"].lower() == V1.lower():
        outflow += amt; outs.append((t["timeStamp"], amt, t["to"], t["hash"]))

print(f"total txs: {len(txs)}  IN: {inflow:.6f} USDC over {len(ins)}  OUT: {outflow:.6f} USDC over {len(outs)}")
print("IN detail:")
for x in ins: print("  ", x)
json.dump({"inflow": inflow, "outflow": outflow, "ins": ins, "outs": outs, "n_txs": len(txs)},
          open("v1_usdc_flows.json", "w"), indent=1)
