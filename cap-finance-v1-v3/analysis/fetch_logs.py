#!/usr/bin/env python3
"""Fetch event logs for Cap Finance contracts (Etherscan V2) and summarize.
Read-only; uses ETHERSCANV2_API_KEY from env (not written to files)."""
import json, os, urllib.request, time, sys

key = os.environ["ETHERSCANV2_API_KEY"]
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")
os.makedirs(outdir, exist_ok=True)

SIGS = {
    # topic0 -> (name, indexed params, data params)
    "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c": "Deposit(address,address,uint256,uint256)",
    "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65": "Withdraw(address,address,uint256,uint256)",
    "0x4c209b5fc8ad50758f13e2e1088ba56a560dff690a1c6fef26394f4c03821c4f": "NewOrder?",
    "0x9b5a77e8e7c8ba4e2ff4c6f1b0b5b95b6e8d5b8e6c8e4e4b0e2b8c4b8e6c8e4e": "?",
}

def get_logs(addr, topic0=None, from_block=0, to_block="latest", offset=1000):
    out = []
    page = 1
    while True:
        url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=logs&action=getLogs"
               f"&fromBlock={from_block}&toBlock={to_block}&address={addr}"
               f"&apikey={key}&offset={offset}&page={page}")
        if topic0:
            url += f"&topic0={topic0}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        res = d.get("result", [])
        if not isinstance(res, list):
            print("ERR", addr, d.get("message"), d.get("result"))
            break
        out.extend(res)
        if len(res) < offset:
            break
        page += 1
        time.sleep(0.25)
    return out

if __name__ == "__main__":
    addr = sys.argv[1]
    topic0 = sys.argv[2] if len(sys.argv) > 2 else None
    logs = get_logs(addr, topic0)
    fn = os.path.join(outdir, f"logs-{addr[:10]}-{(topic0 or 'all')[:12]}.json")
    with open(fn, "w") as f:
        json.dump(logs, f, indent=1)
    print(f"{addr} topic0={topic0}: {len(logs)} logs -> {fn}")
    for l in logs[:3]:
        print(json.dumps(l, indent=1)[:600])
