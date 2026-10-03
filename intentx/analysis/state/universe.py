#!/usr/bin/env python3
"""Enumerate the full partyA account universe per chain via the diamond's
BalanceChangePartyA(address indexed partyA, uint256 amount, uint8 _type) event.

Base: Ankr eth_getLogs (chunked 5M blocks).
Arb/Mantle/Blast: Etherscan V2 (chunked, page escalation).

Writes raw/partyA_universe_<chain>.json
"""
import json
import os
import sys
import time
import requests

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
TOPIC_A = "0x12f926682e9716435703a506b436993346a19a8d2f4378b264fee4c5a87f34a2"

CHAINS = {
    "base": dict(kind="ankr", rpc="https://rpc.ankr.com/base/{key}",
                 diamond="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43"),
    "arb": dict(kind="etherscan", id=42161,
                diamond="0x8F06459f184553e5d04F07F868720BDaCAB39395"),
    "mantle": dict(kind="etherscan", id=5000,
                   diamond="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5"),
    "blast": dict(kind="etherscan", id=81457,
                  diamond="0x3d17f073cCb9c3764F105550B0BCF9550477D266"),
}


def ankr_chunk(cfg, lo, hi):
    url = cfg["rpc"].format(key=os.environ.get("ANKR_API_KEY", ""))
    return requests.post(url, json={"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
                                    "params": [{"address": cfg["diamond"], "topics": [TOPIC_A],
                                                "fromBlock": hex(lo), "toBlock": hex(hi)}]},
                         timeout=180).json()


def run(chain):
    cfg = CHAINS[chain]
    es_key = os.environ.get("ETHERSCANV2_API_KEY", "")
    out_path = os.path.join(RAW, f"partyA_universe_{chain}.json")
    accts = set()
    n_logs = 0
    n_events_est = 0

    if cfg["kind"] == "ankr":
        latest = int(requests.post(cfg["rpc"].format(key=os.environ.get("ANKR_API_KEY", "")),
                                   json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []},
                                   timeout=60).json()["result"], 16)
        CH = 5_000_000
        for lo in range(0, latest + 1, CH):
            hi = min(lo + CH - 1, latest)
            d = ankr_chunk(cfg, lo, hi)
            if "error" in d:
                raise RuntimeError(f"{chain} {lo}-{hi}: {str(d['error'])[:150]}")
            for lg in d["result"]:
                t = lg.get("topics") or []
                if len(t) > 1:
                    accts.add("0x" + t[1][-40:].lower())
                n_logs += 1
            print(f"  [{chain}] {lo}-{hi}: {len(d['result'])} logs, universe={len(accts)}", flush=True)
            time.sleep(0.25)
    else:
        # latest block
        u = f"https://api.etherscan.io/v2/api?chainid={cfg['id']}&module=proxy&action=eth_blockNumber&apikey={es_key}"
        latest = int(requests.get(u, timeout=60).json()["result"], 16)
        CH = 5_000_000
        lo = 0
        while lo <= latest:
            hi = min(lo + CH - 1, latest)
            page = 1
            while True:
                u = (f"https://api.etherscan.io/v2/api?chainid={cfg['id']}&module=logs&action=getLogs"
                     f"&address={cfg['diamond']}&topic0={TOPIC_A}&fromBlock={lo}&toBlock={hi}"
                     f"&offset=1000&page={page}&apikey={es_key}")
                r = requests.get(u, timeout=90).json()
                if r.get("status") != "1":
                    msg = str(r.get("message")) + str(r.get("result"))
                    if "No logs" in msg or "No records" in msg:
                        break
                    raise RuntimeError(f"{chain} {lo}-{hi} p{page}: {msg[:150]}")
                result = r["result"]
                for lg in result:
                    t = lg.get("topics") or []
                    if len(t) > 1:
                        accts.add("0x" + t[1][-40:].lower())
                    n_logs += 1
                if len(result) < 1000:
                    break
                page += 1
                if page > 10:
                    break
                time.sleep(0.25)
            print(f"  [{chain}] {lo}-{hi}: total logs={n_logs}, universe={len(accts)}", flush=True)
            lo = hi + 1
            time.sleep(0.3)

    with open(out_path, "w") as f:
        json.dump({"chain": chain, "topic": TOPIC_A, "log_count": n_logs,
                   "universe_count": len(accts), "accounts": sorted(accts)}, f, indent=1)
    print(f"[{chain}] universe={len(accts)} from {n_logs} BalanceChangePartyA logs")


if __name__ == "__main__":
    for c in sys.argv[1:]:
        run(c)
