#!/usr/bin/env python3
"""Enumerate borrowers of all Bastion markets via Aurora RPC eth_getLogs (adaptive chunking)."""
import requests, json, time, sys
from Crypto.Hash import keccak

R = "https://mainnet.aurora.dev"
BORROW = "0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80"
MARKETS = {
    "cETH":  "0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0",
    "cNEAR": "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
    "cUSDC": "0xe5308dc623101508952948b141fD9eaBd3337D99",
    "cUSDT": "0x845E15A441CFC1871B7AC610b0E922019BaD9826",
    "cWBTC": "0xfa786baC375D8806185555149235AcDb182C033b",
}
session = requests.Session()

def rpc(method, params, retries=5):
    for i in range(retries):
        try:
            r = session.post(R, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=180)
            j = r.json()
            if "error" in j and "Log response size exceeded" not in str(j["error"]) and "rate" not in str(j["error"]).lower():
                # real rpc error
                return j
            return j
        except Exception as e:
            time.sleep(2*(i+1))
    raise RuntimeError("rpc failed")

LATEST = int(rpc("eth_blockNumber", [])["result"], 16)
print("latest block", LATEST)

def fetch_logs(addr, topic, lo, hi, depth=0):
    res = rpc("eth_getLogs", [{"fromBlock": hex(lo), "toBlock": hex(hi), "address": addr, "topics": [topic]}])
    if "error" in res:
        msg = str(res["error"])
        if "Log response size exceeded" in msg and hi > lo:
            mid = (lo + hi) // 2
            if depth > 24:
                raise RuntimeError("too deep")
            a = fetch_logs(addr, topic, hi - (hi-mid) if False else mid+1, hi, depth+1)
            b = fetch_logs(addr, topic, lo, mid, depth+1)
            return a + b
        raise RuntimeError(f"rpc error {msg[:160]}")
    return res.get("result") or []

out = {}
for mn, addr in MARKETS.items():
    t0 = time.time()
    logs = fetch_logs(addr, BORROW, 0, LATEST)
    addrs = {}
    for lg in logs:
        d = lg["data"][2:]
        a = "0x" + d[24:64]
        blk = int(lg["blockNumber"], 16)
        addrs[a] = max(addrs.get(a, 0), blk)
    out[mn] = addrs
    print(mn, "total borrow logs:", len(logs), "unique:", len(addrs), f"{time.time()-t0:.0f}s", flush=True)

json.dump({k: {"count": len(v), "borrowers": v} for k, v in out.items()}, open("borrowers_map.json", "w"), indent=1)
allb = sorted(set().union(*[set(v) for v in out.values()]))
json.dump(allb, open("borrowers_list.json", "w"), indent=1)
print("TOTAL unique borrowers:", len(allb))
