#!/usr/bin/env python3
"""Enumerate all contracts emitting DepositForAccount/WithdrawFromAccount per chain.

Chunked eth_getLogs without address filter. Writes raw/ma_emitters_<chain>.json
"""
import json
import os
import sys
import time
import requests

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
TOPICS = {
    "DepositForAccount": "0xb92f7c65176e3a873589352927ba42330e95085f34ab1a9721f2135b94a51883",
    "WithdrawFromAccount": "0x40e4447d271dea2a920b9669d305a3255d8783d59b016237e63b106f1c9dd5fa",
}
RPCS = {
    "base": "https://rpc.ankr.com/base/{}".format(os.environ.get("ANKR_API_KEY", "")),
    "arb": "https://arbitrum-one-rpc.publicnode.com",
    "mantle": "https://rpc.mantle.xyz",
    "blast": "https://blast-rpc.publicnode.com",
}


def rpc(rpc_url, method, params, tries=6):
    delay = 1.0
    for i in range(tries):
        try:
            r = requests.post(rpc_url, json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=120)
            d = r.json()
            if isinstance(d, dict) and "error" in d and "result" not in d:
                raise RuntimeError(json.dumps(d["error"])[:200])
            return d
        except Exception as e:
            if i == tries - 1:
                raise
            time.sleep(delay)
            delay *= 1.8


def run(chain):
    url = RPCS[chain]
    latest = int(rpc(url, "eth_blockNumber", [])["result"], 16)
    out = {"chain": chain, "latest": latest, "topics": TOPICS, "emitters": {}}
    for tname, topic in TOPICS.items():
        counts = {}
        CH = 10_000_000
        ranges = [(lo, min(lo + CH, latest)) for lo in range(0, latest + 1, CH)]
        while ranges:
            lo, hi = ranges.pop(0)
            try:
                d = rpc(url, "eth_getLogs", [{"topics": [topic], "fromBlock": hex(lo), "toBlock": hex(hi)}])
            except Exception as e:
                if hi - lo > 50_000:
                    mid = (lo + hi) // 2
                    ranges.insert(0, (mid + 1, hi))
                    ranges.insert(0, (lo, mid))
                    continue
                raise
            if "result" not in d:
                raise RuntimeError(str(d)[:200])
            logs = d["result"]
            for lg in logs:
                a = lg["address"].lower()
                counts[a] = counts.get(a, 0) + 1
            print(f"  [{chain}/{tname}] {lo}-{hi}: {len(logs)} logs", flush=True)
            time.sleep(0.2)
        out["emitters"][tname] = counts
    with open(os.path.join(RAW, f"ma_emitters_{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{chain}] emitters:")
    for t, c in out["emitters"].items():
        for a, n in sorted(c.items(), key=lambda kv: -kv[1]):
            print(f"   {t} {a} {n}")


if __name__ == "__main__":
    for c in sys.argv[1:]:
        run(c)
