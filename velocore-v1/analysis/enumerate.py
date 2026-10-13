#!/usr/bin/env python3
"""Enumerate Velocore V1 (zkSync Era) pairs from both factories.
Read-only JSON-RPC calls against a keyless public RPC.
Writes analysis/pairs_raw.json
"""
import json, urllib.request, sys, time

RPC = "https://mainnet.era.zksync.io"
FACTORIES = {
    "F1_0xF571": "0xF5719b1Ea3C9bF6491E22C49379E31060d0FbFc1",
    "F2_0xE140": "0xE140EaC2bB748c8F456719a457F26636617Bb0E9",
}
SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
}

_id = [0]
def rpc_batch(calls):
    """calls: list of (to, data). returns list of results in order (None on error)."""
    payload = []
    for to, data in calls:
        _id[0] += 1
        payload.append({"jsonrpc": "2.0", "id": _id[0], "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.loads(r.read())
            break
        except Exception as e:
            if attempt == 3: raise
            time.sleep(2 * (attempt + 1))
    out = [None] * len(calls)
    if isinstance(res, dict):
        res = [res]
    for item in res:
        idx = None
        for i, (t, d) in enumerate(calls):
            pass
        out[item["id"] - payload[0]["id"]] = item.get("result")
    return out

def call(to, data):
    return rpc_batch([(to, data)])[0]

def chunked(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

def dec_addr(hexstr):
    if not hexstr or len(hexstr) < 42: return None
    return "0x" + hexstr[-40:]

def dec_uint(hexstr):
    if not hexstr or hexstr == "0x": return None
    return int(hexstr, 16)

def main():
    block = rpc_batch([(FACTORIES["F1_0xF571"], "0x" + "00")])  # dummy to get nothing
    block_req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),
        headers={"Content-Type": "application/json","User-Agent":"Mozilla/5.0"})
    with urllib.request.urlopen(block_req, timeout=30) as r:
        block = int(json.loads(r.read())["result"], 16)

    result = {"rpc": "https://mainnet.era.zksync.io (public keyless)", "block": block, "factories": {}}
    all_pairs = []
    for fname, faddr in FACTORIES.items():
        n = dec_uint(call(faddr, SEL["allPairsLength"]))
        pairs = []
        for batch in chunked(range(n), 10):
            res = rpc_batch([(faddr, SEL["allPairs"] + hex(i)[2:].zfill(64)) for i in batch])
            for i, r_ in zip(batch, res):
                pairs.append({"idx": i, "pair": dec_addr(r_)})
        result["factories"][fname] = {"address": faddr, "pair_count": n, "pairs": pairs}
        for p in pairs:
            p["factory"] = fname
            all_pairs.append(p)
    print("total pairs:", len(all_pairs))

    # per-pair: token0, token1, getReserves, totalSupply
    for p in all_pairs:
        a = p["pair"]
        t0, t1, res, ts = rpc_batch([
            (a, SEL["token0"]), (a, SEL["token1"]),
            (a, SEL["getReserves"]), (a, SEL["totalSupply"]),
        ])
        p["token0"] = dec_addr(t0)
        p["token1"] = dec_addr(t1)
        if res and len(res) >= 2 + 64*3:
            p["reserve0"] = str(dec_uint("0x" + res[2:66]))
            p["reserve1"] = str(dec_uint("0x" + res[66:130]))
            p["blockTimestampLast"] = dec_uint("0x" + res[130:194])
        p["lp_totalSupply"] = str(dec_uint(ts)) if ts else None
    # token metadata
    tokens = set()
    for p in all_pairs:
        tokens.add(p["token0"]); tokens.add(p["token1"])
    tokens = sorted(t for t in tokens if t)
    meta = {}
    for batch in chunked(tokens, 10):
        syms = rpc_batch([(t, SEL["symbol"]) for t in batch])
        decs = rpc_batch([(t, SEL["decimals"]) for t in batch])
        for t, s, d in zip(batch, syms, decs):
            sym = None
            if s and len(s) > 130:  # dynamic string
                try:
                    off = int(s[2:66], 16)
                    ln = int(s[66 + 2*off: 66 + 2*off + 64], 16)
                    sym = bytes.fromhex(s[66 + 2*off + 64: 66 + 2*off + 64 + 2*ln]).decode("utf-8", "replace")
                except Exception:
                    sym = None
            elif s and s != "0x":
                try: sym = bytes.fromhex(s[2:]).rstrip(b"\x00").decode("utf-8","replace")
                except Exception: sym = None
            meta[t] = {"symbol": sym, "decimals": dec_uint(d) if d and d != "0x" else None}
    result["tokens"] = meta
    result["pairs"] = all_pairs
    with open("/home/heisenberg/CA/velocore-v1/analysis/pairs_raw.json", "w") as f:
        json.dump(result, f, indent=1)
    print("block:", block)
    print("wrote analysis/pairs_raw.json")

if __name__ == "__main__":
    main()
