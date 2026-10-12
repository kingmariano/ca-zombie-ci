#!/usr/bin/env python3
"""Timeswap V2 — enumerate option pairs via factory getByIndex and read balances.
Read-only: eth_call / eth_getCode / eth_blockNumber only. Keyless public RPCs only.
Usage: python3 enumerate.py [chain ...]   (default: all)
Output: analysis/live-<chain>.json
"""
import json, sys, time, urllib.request, os

HERE = os.path.dirname(os.path.abspath(__file__))

RPC = {
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "base": "https://mainnet.base.org",
    "optimism": "https://mainnet.optimism.io",
    "polygon": "https://polygon.drpc.org",
    "mantle": "https://rpc.mantle.xyz",
    "hyperliquid": "https://rpc.hyperliquid.xyz/evm",
    "xlayer": "https://rpc.xlayer.tech",
    "polygon-zkevm": "https://zkevm-rpc.com",
    "inevm": "https://mainnet.rpc.inevm.com/http",
}

# Option factories per chain (from DefiLlama adapter config, verified on-chain: they expose numberOfPairs()/getByIndex() and revert on optionFactory()).
FACTORIES = {
    "ethereum": ["0xcf0aca5c5b7e1bF63514D362243b6c50d5761FE8", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "arbitrum": ["0xcf0aca5c5b7e1bF63514D362243b6c50d5761FE8", "0x406d3Dfcbe20b642c2262b29b960822975371502", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "base": ["0x406d3Dfcbe20b642c2262b29b960822975371502", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "optimism": ["0x406d3Dfcbe20b642c2262b29b960822975371502", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "polygon": ["0xcAB2E5Ba8b3A8d8Bf8B50F0eec12884D0255fB4A", "0xcf0aca5c5b7e1bF63514D362243b6c50d5761FE8", "0x406d3Dfcbe20b642c2262b29b960822975371502", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "mantle": ["0xf8F5e4B7825d484FBDFDC36fc915E79f30b02f9E", "0x406d3Dfcbe20b642c2262b29b960822975371502", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "hyperliquid": ["0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "xlayer": ["0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "polygon-zkevm": ["0x406d3Dfcbe20b642c2262b29b960822975371502", "0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
    "inevm": ["0x17385e95cb74A20150E4fA092Aa72D57330896C4"],
}

SEL = {
    "numberOfPairs": "0xfc0d92bd",
    "getByIndex": "0x2d883a73",   # getByIndex(uint256)
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "balanceOf": "0x70a08231",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "name": "0x06fdde03",
    "get": "0xc2bc2efc",          # poolFactory.get(address optionPair)
    "optionFactory": "0xb3461c87",
}

def rpc(url, method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)

def batch(url, calls, retries=3):
    """calls: list of (method, params). Returns list of results (None on individual error)."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        data = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                byid = {x["id"]: x for x in res}
                for j in range(len(chunk)):
                    x = byid.get(j, {})
                    out.append(x.get("result") if "result" in x else None)
                break
            except Exception as e:
                if attempt == retries - 1:
                    out.extend([None] * len(chunk))
                else:
                    time.sleep(1.5 * (attempt + 1))
        time.sleep(0.12)
    return out

def enc_uint(v):
    return format(v, "064x")

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def decode_uint(hexs):
    if not hexs or hexs == "0x":
        return None
    return int(hexs, 16)

def decode_addr(hexs):
    if not hexs or len(hexs) < 42:
        return None
    return "0x" + hexs[-40:]

def decode_string(hexs):
    if not hexs or len(hexs) < 130:
        return None
    try:
        b = bytes.fromhex(hexs[2:])
        # dynamic string
        if len(b) >= 64:
            off = int.from_bytes(b[:32], "big")
            if 32 <= off <= len(b) - 32:
                ln = int.from_bytes(b[off:off+32], "big")
                s = b[off+32:off+32+ln]
                return s.decode("utf-8", "replace").strip("\x00")
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None

def run_chain(chain):
    url = RPC[chain]
    t0 = time.time()
    try:
        bn = decode_uint(rpc(url, "eth_blockNumber", [])["result"])
    except Exception as e:
        print(f"[{chain}] RPC FAIL: {e}")
        return
    result = {"chain": chain, "rpc_host": url.split("/")[2], "block": bn, "factories": {}, "pairs": []}
    for fac in FACTORIES[chain]:
        code = rpc(url, "eth_getCode", [fac, "latest"])["result"]
        if not code or code == "0x":
            result["factories"][fac] = {"code": False}
            continue
        n = decode_uint(rpc(url, "eth_call", [{"to": fac, "data": SEL["numberOfPairs"]}, "latest"])["result"])
        result["factories"][fac] = {"code": True, "numberOfPairs": n}
    # collect all pairs
    pair_addrs = []
    for fac in FACTORIES[chain]:
        n = result["factories"][fac].get("numberOfPairs")
        if not n:
            continue
        calls = [("eth_call", [{"to": fac, "data": SEL["getByIndex"] + enc_uint(i)}, "latest"]) for i in range(n)]
        res = batch(url, calls)
        got = [decode_addr(x) for x in res]
        got = [g for g in got if g]
        result["factories"][fac]["pairs"] = got
        pair_addrs.extend(got)
    # dedupe preserving order
    seen = set()
    pairs = []
    for p in pair_addrs:
        if p.lower() not in seen:
            seen.add(p.lower())
            pairs.append(p)
    print(f"[{chain}] block {bn}: {len(pairs)} unique option pairs from {len(result['factories'])} factories")
    # read token0/token1 for each pair
    calls = []
    for p in pairs:
        calls.append(("eth_call", [{"to": p, "data": SEL["token0"]}, "latest"]))
        calls.append(("eth_call", [{"to": p, "data": SEL["token1"]}, "latest"]))
    res = batch(url, calls)
    meta = []
    for i, p in enumerate(pairs):
        t0a = decode_addr(res[2*i]) if res[2*i] else None
        t1a = decode_addr(res[2*i+1]) if res[2*i+1] else None
        meta.append({"pair": p, "token0": t0a, "token1": t1a})
    # read balances of both tokens held by pair + token metadata (decimals/symbol)
    tokens = set()
    for m in meta:
        if m["token0"]: tokens.add(m["token0"].lower())
        if m["token1"]: tokens.add(m["token1"].lower())
    toks = sorted(tokens)
    calls = []
    for t in toks:
        calls.append(("eth_call", [{"to": t, "data": SEL["decimals"]}, "latest"]))
        calls.append(("eth_call", [{"to": t, "data": SEL["symbol"]}, "latest"]))
    res = batch(url, calls)
    tokmeta = {}
    for i, t in enumerate(toks):
        tokmeta[t] = {"decimals": decode_uint(res[2*i]) if res[2*i] else None,
                      "symbol": decode_string(res[2*i+1]) if res[2*i+1] else None}
    calls = []
    idx = []
    for m in meta:
        for side in ("token0", "token1"):
            t = m[side]
            if t:
                calls.append(("eth_call", [{"to": t, "data": SEL["balanceOf"] + enc_addr(m["pair"])}, "latest"]))
                idx.append((m["pair"], side))
    res = batch(url, calls)
    bal = {}
    for (p, side), r in zip(idx, res):
        bal.setdefault(p, {})[side] = decode_uint(r) if r else None
    for m in meta:
        m["balances"] = bal.get(m["pair"], {})
        m["token0_meta"] = tokmeta.get(m["token0"].lower() if m["token0"] else "")
        m["token1_meta"] = tokmeta.get(m["token1"].lower() if m["token1"] else "")
        for side in ("token0", "token1"):
            meta_m = m[side + "_meta"] or {}
            raw = m["balances"].get(side)
            if raw is not None and meta_m.get("decimals") is not None:
                m["balances"][side + "_human"] = raw / (10 ** meta_m["decimals"])
            else:
                m["balances"][side + "_human"] = None
    result["pairs"] = meta
    out = os.path.join(HERE, f"live-{chain}.json")
    with open(out, "w") as f:
        json.dump(result, f, indent=1)
    print(f"[{chain}] wrote {out} ({time.time()-t0:.1f}s)")

if __name__ == "__main__":
    chains = sys.argv[1:] or list(RPC.keys())
    for c in chains:
        if c in RPC:
            run_chain(c)
