#!/usr/bin/env python3
"""Dump getPoolTokenInfo (cash, managed, lastChangeBlock, assetManager) for all pools/tokens.
Env: AEQ_RPC. In: analysis/pools_state.json. Out: analysis/pool_token_info.json"""
import json, os, subprocess, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPC = os.environ.get("AEQ_RPC", "https://bsc-rpc.publicnode.com")
HERE = os.path.dirname(os.path.abspath(__file__))
VAULT = "0xee1c8dbfbf958484c6a4571f5fb7b99b74a54aa7"

def rpc_one(method, params, retries=3):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers={"Content-Type": "application/json",
                                                                     "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                resp = json.loads(r.read())
            return resp.get("result") if "error" not in resp else None
        except Exception:
            if a < retries - 1:
                import time; time.sleep(1 + a)
    return None

def main():
    st = json.load(open(os.path.join(HERE, "pools_state.json")))
    block = st["block"]
    jobs = []
    for pid, p in st["pools"].items():
        for t in (p.get("vaultTokens") or []):
            jobs.append((pid, t))
    print("pool-token pairs:", len(jobs), "block", block, flush=True)
    def call(j):
        pid, t = j
        data = "0xb05f8e48" + pid[2:] + t[2:].rjust(64, "0")
        return rpc_one("eth_call", [{"to": VAULT, "data": data}, hex(block)])
    with ThreadPoolExecutor(max_workers=8) as ex:
        res = list(ex.map(call, jobs))
    out = {}
    for (pid, t), r in zip(jobs, res):
        if not r or r == "0x":
            out.setdefault(pid, {})[t] = None
            continue
        b = bytes.fromhex(r[2:])
        cash = int.from_bytes(b[0:32], "big")
        managed = int.from_bytes(b[32:64], "big")
        last = int.from_bytes(b[64:96], "big")
        am = "0x" + b[108:128].hex()
        out.setdefault(pid, {})[t] = {"cash": str(cash), "managed": str(managed), "lastChangeBlock": last, "assetManager": am}
    json.dump(out, open(os.path.join(HERE, "pool_token_info.json"), "w"), indent=1)
    nz = [(pid, t, v) for pid, tv in out.items() for t, v in tv.items() if v and int(v["managed"]) > 0]
    print("managed>0 entries:", len(nz))
    for pid, t, v in nz[:20]:
        print(" ", pid[:18], t[:12], v)

if __name__ == "__main__":
    main()
