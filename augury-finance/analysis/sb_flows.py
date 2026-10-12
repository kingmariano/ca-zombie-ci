#!/usr/bin/env python3
"""USDC in/out flows for the 4 AuguryStateBasedDividendsV1 contracts + recent txs."""
import json, urllib.request, time, os
KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
UA = {"User-Agent": "Mozilla/5.0"}
USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
SBS = {
 "SB0_OMEN": "0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3",
 "SB1_OMENUSDC": "0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E",
 "SB17_OMENWETH": "0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238",
 "SB18_OMENWPOL": "0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26",
}

def get(url):
    req = urllib.request.Request(url, headers=UA)
    for a in range(4):
        try: return json.loads(urllib.request.urlopen(req, timeout=45).read())
        except Exception:
            if a == 3: raise
            time.sleep(2)

out = {}
for name, addr in SBS.items():
    txs = []
    for page in range(1, 5):
        url = (f"https://api.etherscan.io/v2/api?chainid=137&module=account&action=tokentx"
               f"&contractaddress={USDC}&address={addr}&page={page}&offset=1000&sort=desc&apikey={KEY}")
        d = get(url); r = d.get("result", [])
        if not isinstance(r, list) or not r: break
        txs += r
        if len(r) < 1000: break
    inflow = outflow = 0; last_ts = 0; first_ts = None
    for t in txs:
        amt = int(t["value"]) / 1e6
        ts = int(t["timeStamp"])
        last_ts = max(last_ts, ts)
        if t["to"].lower() == addr.lower(): inflow += amt
        elif t["from"].lower() == addr.lower(): outflow += amt
        if first_ts is None: first_ts = ts
    # balances
    out[name] = {"addr": addr, "n_txs": len(txs), "inflow": inflow, "outflow_window": outflow,
                 "latest_tx_ts": last_ts, "latest_tx_utc": time.strftime("%Y-%m-%d %H:%M", time.gmtime(last_ts)) if last_ts else None}
    print(name, json.dumps(out[name]))

json.dump(out, open("sb_usdc_flows.json", "w"), indent=1)
