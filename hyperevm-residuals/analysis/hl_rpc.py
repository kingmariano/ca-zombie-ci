#!/usr/bin/env python3
"""Minimal HyperEVM (chainid 999) JSON-RPC helper for read-only calls."""
import json, sys, urllib.request, time

RPC = "https://rpc.hyperliquid.xyz/evm"
_id = 0

def rpc(method, params):
    global _id
    _id += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                out = json.loads(r.read())
            if "result" in out:
                return out["result"]
            raise RuntimeError(f"rpc error: {out.get('error')}")
        except Exception as e:
            if attempt == 3:
                raise
            time.sleep(1.5 * (attempt + 1))

def batch(calls, chunk=20):
    """calls: list of (method, params). Returns list of results (None on error). Chunked + retried."""
    all_res = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        all_res.extend(_batch_once(part))
    return all_res

def _batch_once(calls):
    global _id
    payload = []
    for m, p in calls:
        _id += 1
        payload.append({"jsonrpc": "2.0", "id": _id, "method": m, "params": p})
    body = json.dumps(payload).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            if isinstance(out, dict):
                # whole-batch error; fall back to individual
                raise RuntimeError(f"batch error: {out.get('error')}")
            byid = {o["id"]: o for o in out if isinstance(o, dict)}
            return [(byid.get(o["id"], {}) or {}).get("result") for o in payload]
        except Exception as e:
            last = e
            time.sleep(1.5 * (attempt + 1))
    # final fallback: one-by-one
    res = []
    for m, p in calls:
        try:
            res.append(rpc(m, p))
        except Exception:
            res.append(None)
    return res

def eth_call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])

def get_code(addr, block="latest"):
    return rpc("eth_getCode", [addr, block])

def get_balance(addr, block="latest"):
    return int(rpc("eth_getBalance", [addr, block]), 16)

def block_number():
    return int(rpc("eth_blockNumber", []), 16)

def storage(addr, slot, block="latest"):
    return rpc("eth_getStorageAt", [addr, slot, block])

# --- ABI helpers ---
_SEL_CACHE = {
    "balanceOf(address)": "0x70a08231",
    "totalSupply()": "0x18160ddd",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "owner()": "0x8da5cb5b",
    "admin()": "0xf851a440",
    "allPairsLength()": "0x574f2ba3",
    "allPoolsLength()": "0xefde4e64",
    "allPools(uint256)": "0x41d1de97",
    "length()": "0x1f7b6d32",
    "totalWeight()": "0x96c82e57",
    "minter()": "0x07546172",
    "activePeriod()": "0x77a127ac",
    "epoch()": "0x900cf0cf",
    "getImplementation()": "0xaaf10f42",
    "implementation()": "0x5c60da1b",
    "poolDeployer()": "0x3119049a",
    "numPools()": "0xa8246a9c",
    "locked(uint256)": "0x4b9b3b41",
    "veNEST()": "0x4c73e5cd",
    "voter()": "0x46c96aac",
    "factory()": "0xc45a0155",
    "gaugeManager()": "0xcbda3cee",
    "poolImplementation()": "0xcefa7799",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "fee()": "0xddca3f43",
    "liquidity()": "0x1a686502",
    "gauge()": "0xa6f19c84",
    "isPool(address)": "0x5b16ebb7",
    "protocolFeeManager()": "0xa70dbaeb",
    "swapFeeManager()": "0xd574afa9",
    "tickSpacing()": "0xd0c93a7c",
    "getReserves()": "0x0902f1ac",
}

def enc_sel(sig):
    if sig in _SEL_CACHE:
        return _SEL_CACHE[sig]
    import subprocess
    s = subprocess.run(["cast", "sig", sig], capture_output=True, text=True).stdout.strip()
    _SEL_CACHE[sig] = s
    return s

def call_u256(to, sig, args=(), block="latest"):
    data = enc_sel(sig)
    if args:
        data += "".join(f"{a:064x}" for a in args)
    out = eth_call(to, data, block)
    if out in (None, "0x"):
        return None
    return int(out, 16)

def call_str(to, sig, block="latest"):
    data = enc_sel(sig)
    out = eth_call(to, data, block)
    if not out or out == "0x":
        return None
    b = bytes.fromhex(out[2:])
    if len(b) >= 64:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off+32], "big")
        return b[off+32:off+32+ln].decode(errors="replace")
    return None

def call_addr(to, sig, args=(), block="latest"):
    data = enc_sel(sig)
    if args:
        data += "".join(f"{a:064x}" for a in args)
    out = eth_call(to, data, block)
    if not out or out == "0x" or len(out) < 42:
        return None
    return "0x" + out[-40:]

if __name__ == "__main__":
    print("block:", block_number())
