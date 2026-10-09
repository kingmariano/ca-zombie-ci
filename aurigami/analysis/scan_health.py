#!/usr/bin/env python3
"""Scan all Aurigami borrowers for shortfall (liquidatable positions) at latest block."""
import glob
import json
import os
import sys
import time
import urllib.request

RPC = "https://mainnet.aurora.dev"
UNIT = "0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"
OUT = "/home/heisenberg/CA/aurigami/analysis/health_scan.json"


def rpc_batch(calls):
    """calls: list of (to, data) -> list of results (None on error)."""
    payload = json.dumps([{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                           "params": [{"to": t, "data": d}, "latest"]}
                          for i, (t, d) in enumerate(calls)]).encode()
    req = urllib.request.Request(RPC, data=payload,
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            out = json.load(urllib.request.urlopen(req, timeout=90))
            res = {}
            for item in out:
                res[item["id"]] = item.get("result") if "error" not in item else {"error": item["error"].get("message")}
            return [res.get(i) for i in range(len(calls))]
        except Exception as e:
            print("retry batch:", e, flush=True)
            time.sleep(3)
    return [None] * len(calls)


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def word(v):
    if isinstance(v, str) and v.startswith("0x") and len(v) >= 66:
        return int(v[2:66], 16)
    return None


def main():
    addrs = set()
    for f in glob.glob("/home/heisenberg/CA/aurigami/analysis/borrowers_*.json"):
        addrs.update(json.load(open(f)).keys())
    addrs = sorted(addrs)
    print("unique borrowers:", len(addrs), flush=True)

    # pass 1: getAccountLiquidity (selector 0x5ec88c79)
    results = {}
    B = 20
    for i in range(0, len(addrs), B):
        chunk = addrs[i:i + B]
        calls = [(UNIT, "0x5ec88c79" + enc_addr(a)) for a in chunk]
        outs = rpc_batch(calls)
        for a, o in zip(chunk, outs):
            if isinstance(o, dict):
                results[a] = {"revert": o.get("error")}
            elif isinstance(o, str) and len(o) >= 130:
                liq = int(o[2:66], 16)
                short = int(o[66:130], 16)
                results[a] = {"liquidity": liq, "shortfall": short}
            else:
                results[a] = {"other": o}
        if i % 400 == 0:
            print(f"  scanned {i}/{len(addrs)}", flush=True)
    json.dump(results, open(OUT, "w"), indent=1)
    short_addrs = [a for a, r in results.items() if r.get("shortfall")]
    print("with shortfall:", len(short_addrs), flush=True)
    for a in short_addrs:
        print(" SHORT", a, results[a], flush=True)


if __name__ == "__main__":
    main()
