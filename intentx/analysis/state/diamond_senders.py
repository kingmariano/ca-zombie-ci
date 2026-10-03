#!/usr/bin/env python3
"""Fetch diamond Deposit sender distribution per chain (Etherscan V2) to identify
all MultiAccount funding paths. Writes raw/diamond_deposit_senders_<chain>.json
"""
import json
import os
import sys
import time
import requests

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
TOPIC_DEP = "0x5548c837ab068cf56a2c2479df0882a4922fd203edb7517321831d95078c5f62"
CHAINS = {"arb": (42161, "0x8F06459f184553e5d04F07F868720BDaCAB39395"),
          "mantle": (5000, "0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5"),
          "blast": (81457, "0x3d17f073cCb9c3764F105550B0BCF9550477D266")}


def run(chain):
    cid, diamond = CHAINS[chain]
    key = os.environ["ETHERSCANV2_API_KEY"]
    u = f"https://api.etherscan.io/v2/api?chainid={cid}&module=proxy&action=eth_blockNumber&apikey={key}"
    latest = int(requests.get(u, timeout=60).json()["result"], 16)
    senders = {}
    n = 0
    total = 0
    dec = 6 if chain == "arb" else 18
    CH = 5_000_000
    lo = 0
    while lo <= latest:
        hi = min(lo + CH - 1, latest)
        page = 1
        while True:
            u = (f"https://api.etherscan.io/v2/api?chainid={cid}&module=logs&action=getLogs"
                 f"&address={diamond}&topic0={TOPIC_DEP}&fromBlock={lo}&toBlock={hi}"
                 f"&offset=1000&page={page}&apikey={key}")
            r = requests.get(u, timeout=90).json()
            if r.get("status") != "1":
                msg = str(r.get("message")) + str(r.get("result"))
                if "No logs" in msg or "No records" in msg:
                    break
                raise RuntimeError(f"{chain} {lo}-{hi} p{page}: {msg[:150]}")
            for lg in r["result"]:
                data = lg["data"][2:]
                s = "0x" + data[24:64]
                senders[s] = senders.get(s, 0) + 1
                n += 1
                total += int(data[128:192], 16)
            if len(r["result"]) < 1000:
                break
            page += 1
            if page > 10:
                break
            time.sleep(0.25)
        print(f"  [{chain}] {lo}-{hi}: n={n} senders={len(senders)}", flush=True)
        lo = hi + 1
        time.sleep(0.3)
    out = {"chain": chain, "deposit_count": n, "deposit_total_token": total / 10 ** dec,
           "senders": senders}
    with open(os.path.join(RAW, f"diamond_deposit_senders_{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{chain}] {n} deposits, {len(senders)} senders, total {total/10**dec:,.2f}")


if __name__ == "__main__":
    for c in sys.argv[1:]:
        run(c)
