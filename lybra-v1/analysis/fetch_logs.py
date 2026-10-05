#!/usr/bin/env python3
"""Fetch Lybra V1 events from Etherscan V2 (read-only). Saves raw JSON to analysis/."""
import json, os, sys, time, urllib.request, urllib.parse

API = "https://api.etherscan.io/v2/api"
KEY = os.environ["ETHERSCANV2_API_KEY"]
LYBRA = "0x97de57eC338AB5d51557DA3434828C5DbFaDA371"

TOPICS = {
    "DepositEther": "0x819557bb6c528588eb5c050cf4dd54b96956b6f93a5232c6b429d19e95fe8e89",
    "LiquidationRecord": "0xb59dc9737d55b75fc6ca7522e82d6161da5d7c8337b9ab990a5846f95b5ccdad",
    "Mint": "0x2f00e3cdd69a77be7ed215ec7b2a36784dd158f921fca79ac29deffa353fe6ee",
    "Burn": "0x5d624aa9c148153ab3446c1b154f660ee7701e549fe9b62dab7171b1c80e6fa2",
    "WithdrawEther": "0x7af7d9e5b71152303ff7a5221e1a22febc3cf6407ea2a05f870d770097177db0",
    "RigidRedemption": "0x1a7ab636ab77b4d93c0afba804a009a127e77def45e623e572144ca8f8a03ac5",
}

def get(params):
    params["chainid"] = "1"
    params["apikey"] = KEY
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                d = json.loads(r.read())
            if d.get("status") == "1" or d.get("message") == "No records found":
                return d
            if "rate limit" in str(d.get("result", "")).lower() or d.get("status") == "0":
                time.sleep(1.5 + attempt * 2)
                continue
            return d
        except Exception as e:
            time.sleep(2 + attempt * 2)
    return {"status": "0", "result": []}

def fetch(name, topic):
    out = []
    page = 1
    while True:
        d = get({"module": "logs", "action": "getLogs", "address": LYBRA,
                 "fromBlock": "0", "toBlock": "latest", "topic0": topic,
                 "page": str(page), "offset": "1000"})
        res = d.get("result") or []
        if not isinstance(res, list) or len(res) == 0:
            break
        out.extend(res)
        print(f"  {name}: page {page} -> {len(res)} (total {len(out)})", flush=True)
        if len(res) < 1000:
            break
        page += 1
        time.sleep(0.4)
    with open(f"analysis/logs_{name}.json", "w") as f:
        json.dump(out, f)
    print(f"{name}: {len(out)} events", flush=True)
    return out

if __name__ == "__main__":
    for name, topic in TOPICS.items():
        fetch(name, topic)
