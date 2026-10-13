#!/usr/bin/env python3
"""Enumerate AutoShark finsFactory pairs (BSC), reserves, LP supply, feeTo LP balances,
and skim-able excess (actual token balance vs reserve) per pair.
Read-only. Public keyless RPC only.
"""
import json, time, sys
import requests
from eth_utils import to_checksum_address

RPC = "https://bsc-rpc.publicnode.com"
FACTORY = "0xe759Dd4B9f99392Be64f1050a6A8018f73B53a13"
FEE_TO = "0x593CC303170367FCB249abdd08Aaaa736d552BA5"

SEL = {
    "allPairs": "0x1e3dd18b",          # allPairs(uint256)
    "allPairsLength": "0x574f2ba3",    # allPairsLength()
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "name": "0x06fdde03",
}

def enc_uint(v):
    return hex(v)[2:].rjust(64, "0")

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

class Batch:
    def __init__(self):
        self.calls = []
    def add(self, to, data, tag):
        self.calls.append((to, data, tag))
    def run(self, chunk=100):
        out = {}
        for i in range(0, len(self.calls), chunk):
            part = self.calls[i:i+chunk]
            payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]}
                       for j, (to, data, tag) in enumerate(part)]
            for attempt in range(5):
                try:
                    r = requests.post(RPC, json=payload, timeout=60,
                                      headers={"User-Agent": "research/1.0"})
                    res = r.json()
                    if isinstance(res, list):
                        for j, item in enumerate(res):
                            out[part[j][2]] = item.get("result")
                        break
                except Exception as e:
                    time.sleep(2 + attempt * 2)
            else:
                raise RuntimeError("batch failed")
        return out

def dec_str(h):
    if h is None or h == "0x":
        return None
    b = bytes.fromhex(h[2:])
    if len(b) >= 64:
        # dynamic string: offset 32, len, data
        try:
            ln = int.from_bytes(b[32:64], "big")
            return b[64:64+ln].decode("utf-8", "ignore")
        except Exception:
            pass
    s = b.rstrip(b"\x00")
    return s.decode("utf-8", "ignore") if s else None

def main():
    blk = requests.post(RPC, json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []},
                        timeout=30).json()["result"]
    block = int(blk, 16)
    print("latest block", block)
    l = requests.post(RPC, json={"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                                 "params": [{"to": FACTORY, "data": SEL["allPairsLength"]}, "latest"]},
                      timeout=30).json()["result"]
    n = int(l, 16)
    print("allPairsLength", n)

    b = Batch()
    for i in range(n):
        b.add(FACTORY, SEL["allPairs"] + enc_uint(i), f"p{i}")
    pairs = b.run(100)
    pair_list = []
    for i in range(n):
        r = pairs.get(f"p{i}")
        if r and r != "0x":
            pair_list.append(to_checksum_address("0x" + r[-40:]))
    print("pairs found", len(pair_list))

    b = Batch()
    for p in pair_list:
        b.add(p, SEL["token0"], f"{p}:t0")
        b.add(p, SEL["token1"], f"{p}:t1")
        b.add(p, SEL["getReserves"], f"{p}:res")
        b.add(p, SEL["totalSupply"], f"{p}:ts")
        b.add(p, SEL["balanceOf"] + enc_addr(FEE_TO), f"{p}:feetolp")
    r1 = b.run(120)

    tokens = set()
    raw = {}
    for p in pair_list:
        t0 = r1.get(f"{p}:t0"); t1 = r1.get(f"{p}:t1")
        if not t0 or not t1:
            continue
        t0 = to_checksum_address("0x" + t0[-40:])
        t1 = to_checksum_address("0x" + t1[-40:])
        tokens.add(t0); tokens.add(t1)
        res = r1.get(f"{p}:res")
        reserves = None
        if res and res != "0x":
            rb = bytes.fromhex(res[2:])
            if len(rb) >= 96:
                reserves = [int.from_bytes(rb[0:32], "big"), int.from_bytes(rb[32:64], "big")]
        ts = r1.get(f"{p}:ts")
        feetolp = r1.get(f"{p}:feetolp")
        raw[p] = {"token0": t0, "token1": t1, "reserves": reserves,
                  "totalSupply": int(ts, 16) if ts and ts != "0x" else None,
                  "feeToLP": int(feetolp, 16) if feetolp and feetolp != "0x" else None}

    # actual token balances of each pair (skim check) + token metadata
    b = Batch()
    for p, d in raw.items():
        b.add(d["token0"], SEL["balanceOf"] + enc_addr(p), f"{p}:bal0")
        b.add(d["token1"], SEL["balanceOf"] + enc_addr(p), f"{p}:bal1")
    for t in tokens:
        b.add(t, SEL["symbol"], f"{t}:sym")
        b.add(t, SEL["decimals"], f"{t}:dec")
    r2 = b.run(150)

    for p, d in raw.items():
        d["bal0"] = int(r2[f"{p}:bal0"], 16) if r2.get(f"{p}:bal0") else None
        d["bal1"] = int(r2[f"{p}:bal1"], 16) if r2.get(f"{p}:bal1") else None

    tokmeta = {}
    for t in tokens:
        sym = dec_str(r2.get(f"{t}:sym"))
        dec = int(r2[f"{t}:dec"], 16) if r2.get(f"{t}:dec") and r2[f"{t}:dec"] != "0x" else None
        tokmeta[t] = {"symbol": sym, "decimals": dec}

    out = {"block": block, "factory": FACTORY, "feeTo": FEE_TO, "n_pairs": len(pair_list),
           "tokens": tokmeta, "pairs": raw}
    with open("/home/heisenberg/CA/autoshark/analysis/pairs_raw.json", "w") as f:
        json.dump(out, f, indent=1)
    print("saved; pairs with reserves:", sum(1 for d in raw.values() if d["reserves"]))

if __name__ == "__main__":
    main()
