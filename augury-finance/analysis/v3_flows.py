#!/usr/bin/env python3
"""Pull all USDC transfers to/from DividendsV3 (0xf9dF...)."""
import json, urllib.request, time, os
KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
UA = {"User-Agent": "Mozilla/5.0"}
V3 = "0xf9dF350c1e9888452E4E7fd7A014503FA0eaB7e4"
USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

def get(url):
    req = urllib.request.Request(url, headers=UA)
    for a in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=40).read())
        except Exception:
            if a == 3: raise
            time.sleep(2)

txs = []
for page in range(1, 12):
    url = (f"https://api.etherscan.io/v2/api?chainid=137&module=account&action=tokentx"
           f"&contractaddress={USDC}&address={V3}&page={page}&offset=1000&sort=asc&apikey={KEY}")
    d = get(url)
    r = d.get("result", [])
    if not isinstance(r, list) or not r:
        print("page", page, "empty, status", d.get("status"), d.get("message")); break
    txs += r
    print("page", page, "got", len(r))
    if len(r) < 1000: break

inflow = outflow = 0
ins, outs = [], []
for t in txs:
    amt = int(t["value"]) / 1e6
    if t["to"].lower() == V3.lower():
        inflow += amt; ins.append((int(t["timeStamp"]), amt, t["from"], t["hash"]))
    elif t["from"].lower() == V3.lower():
        outflow += amt; outs.append((int(t["timeStamp"]), amt, t["to"], t["hash"]))

print(f"total txs: {len(txs)}  IN: {inflow:.6f} over {len(ins)}  OUT: {outflow:.6f} over {len(outs)}")
print("IN detail (first 40):")
for x in ins[:40]: print("  ", x)
json.dump({"inflow": inflow, "outflow": outflow, "ins": ins, "outs": outs, "n_txs": len(txs)},
          open("v3_usdc_flows.json", "w"), indent=1)
