#!/usr/bin/env python3
"""Enumerate ALL ERC20 Approval events to the Socket Gateway (Ethereum) via Etherscan V2 getLogs,
paginated (1000/page). Read-only. Output: socket_approvals_raw.json
Usage: python3 socket_approvals_scan.py [max_pages]
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV["ETHERSCANV2_API_KEY"]
UA = {"User-Agent": "zombie-hunt/read-only"}
GW = "0x3a23F943181408EAC424116Af7b7790c94Cb97a5"
APPROVAL_TOPIC = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
GW_TOPIC = "0x" + "0" * 24 + GW[2:].lower()

def get(url):
    req = urllib.request.Request(url, headers=UA)
    for i in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception:
            time.sleep(1.5 * (i + 1))
    raise RuntimeError("fetch failed")

def main():
    max_pages = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    # creation block
    d = get(f"https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getcontractcreation"
            f"&contractaddresses={GW}&apikey={KEY}")
    txh = d["result"][0]["txHash"]
    d2 = get(f"https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getTransactionByHash"
             f"&txhash={txh}&apikey={KEY}")
    start = int(d2["result"]["blockNumber"], 16)
    print("gateway deployed at block", start, "tx", txh)
    events = []
    page = 1
    while page <= max_pages:
        url = (f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs"
               f"&fromBlock={start}&toBlock=latest&topic0={APPROVAL_TOPIC}"
               f"&topic0_2_opr=and&topic2={GW_TOPIC}&page={page}&offset=1000&apikey={KEY}")
        d = get(url)
        res = d.get("result")
        if not isinstance(res, list) or not res:
            print("end at page", page, "status", d.get("status"), str(res)[:100])
            break
        for e in res:
            events.append({"block": int(e["blockNumber"], 16), "tx": e["transactionHash"],
                           "token": e["address"].lower(),
                           "owner": "0x" + e["topics"][1][-40:],
                           "value": int(e["data"], 16) if e["data"] and e["data"] != "0x" else 0})
        print("page", page, "total", len(events), flush=True)
        if len(res) < 1000:
            break
        page += 1
        time.sleep(0.25)
    json.dump({"gateway": GW, "deploy_block": start, "events": events},
              open(os.path.join(HERE, "socket_approvals_raw.json"), "w"))
    print("saved", len(events), "approval events")

if __name__ == "__main__":
    main()
