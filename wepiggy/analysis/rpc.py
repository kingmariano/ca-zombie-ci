"""Minimal JSON-RPC batch helper + ABI decoders for WePiggy fork-state enumeration.
Read-only: eth_call / eth_getStorageAt / eth_getCode only.
"""
import json, os, sys, time
import urllib.request

def _rpc(url, method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    last = None
    for i in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                out = json.loads(r.read().decode())
            if "result" in out:
                return out["result"]
            last = out.get("error")
        except Exception as e:
            last = str(e)
        time.sleep(1.0 + i)
    raise RuntimeError(f"rpc {method} failed: {last}")

def _batch_once(url, calls):
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]})
    body = json.dumps(payload).encode()
    last = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.loads(r.read().decode())
            if isinstance(out, dict):
                out = [out]
            res = [None] * len(calls)
            for item in out:
                i = item["id"]
                res[i] = item.get("result") if "result" in item else None
            return res
        except Exception as e:
            last = str(e)
            time.sleep(1.5 + attempt)
    raise RuntimeError(f"batch failed: {last}")

def batch(url, calls, chunk=24):
    """calls: list of (to, data) hex. Returns list of hex results (or None on per-call error).
    Chunked to stay under public-RPC request-size limits (OP mainnet: HTTP 413 above ~32 calls)."""
    res = []
    for i in range(0, len(calls), chunk):
        res.extend(_batch_once(url, calls[i:i+chunk]))
    return res

def call(url, to, sig, arg=None):
    data = sig if arg is None else sig + arg
    try:
        return _rpc(url, "eth_call", [{"to": to, "data": data}, "latest"])
    except Exception:
        return None

def to_int(hexstr):
    if hexstr is None or hexstr == "" or hexstr == "0x":
        return None
    return int(hexstr, 16)

def as_addr(hexstr):
    if not hexstr or len(hexstr) < 42:
        return None
    return "0x" + hexstr[-40:]

def as_bool(hexstr):
    v = to_int(hexstr)
    return None if v is None else bool(v)

def as_string(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    b = bytes.fromhex(hexstr[2:])
    if len(b) < 64:
        return None
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off+32], "big")
        return b[off+32:off+32+ln].decode("utf8", errors="replace")
    except Exception:
        return None

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

# ---- selectors (verified locally with `cast sig`) ----
SEL = {
    "getAllMarkets": "0xb0772d0b",
    "underlying": "0x6f307dc3",
    "cash": "0x961be391",
    "totalSupply": "0x18160ddd",
    "totalBorrows": "0x47bd3718",
    "totalReserves": "0x8f840ddd",
    "exchangeRateStored": "0x182df0f5",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "comptroller": "0x5fe3b567",
    "admin": "0xf851a440",
    "oracle": "0x7dc0d1d0",
    "closeFactorMantissa": "0xe8755446",
    "liquidationIncentiveMantissa": "0x4ada90af",
    "markets": "0x8e8f294b",
    "mintGuardianPaused": "0x731f0c2b",
    "borrowGuardianPaused": "0x6d154ea5",
    "transferGuardianPaused": "0xa3690086",
    "seizeGuardianPaused": "0xac0b0bb7",
    "borrowCaps": "0x4a584432",
    "getUnderlyingPrice": "0xfc57d4df",
    "comptrollerImplementation": "0xbb82aa5e",
    "pendingAdmin": "0x26782247",
    "pauseGuardian": "0x24a3d622",
    "reserveFactorMantissa": "0x173b9904",
    "accrualBlockNumber": "0x6c540baf",
    "borrowIndex": "0xaa5af0fd",
    "exchangeRateCurrent": "0xbd6d894d",
    "protocolSeizeShareMantissa": "0x6752e702",
    "interestRateModel": "0xf3fdb15a",
    "name": "0x06fdde03",
    "getCash": "0x3b1d21a2",
    "implementation": "0x5c60da1b",   # EIP-1967 impl getter (non-standard) & proxy
}

def enumerate_comptroller(url, comptroller, verbose=True):
    """Full state dump for a Compound-v2-fork comptroller + its markets."""
    res = {"comptroller": comptroller, "url": url, "markets": []}
    raw = call(url, comptroller, SEL["getAllMarkets"])
    if not raw:
        raise RuntimeError("getAllMarkets failed")
    b = bytes.fromhex(raw[2:])
    off = int.from_bytes(b[0:32], "big")
    n = int.from_bytes(b[off:off+32], "big")
    markets = []
    for i in range(n):
        w = b[off+32+i*32: off+64+i*32]
        markets.append("0x" + w[12:].hex())
    res["market_count"] = len(markets)
    # comptroller-level reads
    cscalars = {}
    cscalars["admin"] = as_addr(call(url, comptroller, SEL["admin"]))
    cscalars["oracle"] = as_addr(call(url, comptroller, SEL["oracle"]))
    cscalars["closeFactorMantissa"] = to_int(call(url, comptroller, SEL["closeFactorMantissa"]))
    cscalars["liquidationIncentiveMantissa"] = to_int(call(url, comptroller, SEL["liquidationIncentiveMantissa"]))
    cscalars["pauseGuardian"] = as_addr(call(url, comptroller, SEL["pauseGuardian"]))
    cscalars["pendingAdmin"] = as_addr(call(url, comptroller, SEL["pendingAdmin"]))
    cscalars["comptrollerImplementation"] = as_addr(call(url, comptroller, SEL["comptrollerImplementation"]))
    cscalars["seizeGuardianPaused"] = as_bool(call(url, comptroller, SEL["seizeGuardianPaused"]))
    res["comptroller_state"] = cscalars
    oracle = cscalars["oracle"]
    # per-market reads (batched)
    calls = []
    idx = {}
    def add(key, to, sig, arg=None):
        data = sig if arg is None else sig + arg
        idx.setdefault(key, len(calls))
        calls.append((to, data))
    for m in markets:
        add(("cash", m), m, SEL["getCash"])
        add(("totalSupply", m), m, SEL["totalSupply"])
        add(("totalBorrows", m), m, SEL["totalBorrows"])
        add(("totalReserves", m), m, SEL["totalReserves"])
        add(("exchangeRateStored", m), m, SEL["exchangeRateStored"])
        add(("accrualBlockNumber", m), m, SEL["accrualBlockNumber"])
        add(("borrowIndex", m), m, SEL["borrowIndex"])
        add(("reserveFactor", m), m, SEL["reserveFactorMantissa"])
        add(("underlying", m), m, SEL["underlying"])
        add(("sym", m), m, SEL["symbol"])
        add(("markets", m), comptroller, SEL["markets"], enc_addr(m))
        add(("mintPaused", m), comptroller, SEL["mintGuardianPaused"], enc_addr(m))
        add(("borrowPaused", m), comptroller, SEL["borrowGuardianPaused"], enc_addr(m))
        add(("transferPaused", m), comptroller, SEL["transferGuardianPaused"], enc_addr(m))
        add(("borrowCap", m), comptroller, SEL["borrowCaps"], enc_addr(m))
        add(("price", m), oracle, SEL["getUnderlyingPrice"], enc_addr(m))
        add(("irm", m), m, SEL["interestRateModel"])
    r = batch(url, calls)
    for m in markets:
        def g(k):
            i = idx.get((k, m))
            return r[i] if i is not None and i < len(r) else None
        mk = g("markets") or ""
        isListed = bool(to_int(mk[:66]))
        cf = to_int("0x" + mk[66:130]) if len(mk) >= 130 else None
        entry = {
            "cToken": m,
            "symbol": as_string(g("sym")),
            "underlying": as_addr(g("underlying")),
            "cash": to_int(g("cash")),
            "totalSupply": to_int(g("totalSupply")),
            "totalBorrows": to_int(g("totalBorrows")),
            "totalReserves": to_int(g("totalReserves")),
            "exchangeRateStored": to_int(g("exchangeRateStored")),
            "accrualBlockNumber": to_int(g("accrualBlockNumber")),
            "borrowIndex": to_int(g("borrowIndex")),
            "reserveFactorMantissa": to_int(g("reserveFactor")),
            "isListed": isListed,
            "collateralFactorMantissa": cf,
            "mintGuardianPaused": as_bool(g("mintPaused")),
            "borrowGuardianPaused": as_bool(g("borrowPaused")),
            "transferGuardianPaused": as_bool(g("transferPaused")),
            "borrowCap": to_int(g("borrowCap")),
            "oraclePrice": to_int(g("price")),
            "interestRateModel": as_addr(g("irm")),
        }
        res["markets"].append(entry)
    return res

if __name__ == "__main__":
    url = sys.argv[1]
    comp = sys.argv[2]
    out = enumerate_comptroller(url, comp)
    print(json.dumps(out, indent=1))
