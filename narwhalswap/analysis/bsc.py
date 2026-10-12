#!/usr/bin/env python3
"""Shared BSC RPC helpers (keyless public endpoints; no secrets). Stdlib only."""
import json, time, urllib.request, urllib.error

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-ci"}
RPCS = [
    "https://bsc-rpc.publicnode.com",
    "https://1rpc.io/bnb",
    "https://bsc-dataseed.bnbchain.org",
    "https://bsc-dataseed1.defibit.io",
]
_lastgood = {"i": 0}

def _call_raw(url, payload, timeout):
    req = urllib.request.Request(url, data=payload, headers={**UA, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def rpc(method, params, timeout=25):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    errs = []
    for k in range(len(RPCS)):
        url = RPCS[(_lastgood["i"] + k) % len(RPCS)]
        try:
            d = _call_raw(url, body, timeout)
            if "result" in d:
                _lastgood["i"] = (_lastgood["i"] + k) % len(RPCS)
                return d["result"]
            errs.append(str(d.get("error"))[:120])
            # node-level revert => do not rotate
            if "execution reverted" in errs[-1] or "revert" in errs[-1]:
                raise RpcRevert(errs[-1])
        except RpcRevert:
            raise
        except Exception as e:
            errs.append(str(e)[:120])
    raise RuntimeError("all rpcs failed: " + " | ".join(errs[-3:]))

class RpcRevert(Exception):
    pass

def rpc_batch(calls, timeout=60):
    """calls: list of (method, params). Returns list of results (None if node reverted)."""
    payload = json.dumps([{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                          for i, (m, p) in enumerate(calls)]).encode()
    errs = []
    for k in range(len(RPCS)):
        url = RPCS[(_lastgood["i"] + k) % len(RPCS)]
        try:
            d = _call_raw(url, payload, timeout)
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item.get("result")  # None when error
                _lastgood["i"] = (_lastgood["i"] + k) % len(RPCS)
                return out
            errs.append(str(d)[:120])
        except Exception as e:
            errs.append(str(e)[:120])
    raise RuntimeError("all rpcs failed: " + " | ".join(errs[-3:]))

def block_number():
    return int(rpc("eth_blockNumber", []), 16)

def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])

def code(addr, block="latest"):
    return rpc("eth_getCode", [addr, block])

# --- ABI helpers -------------------------------------------------------------
def selector(sig):
    import hashlib
    return "0x" + hashlib.sha3_256(sig.encode()).hexdigest()[:8]  # NOT used; evm uses keccak

# use precomputed selectors (keccak) to avoid dependency
SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "feeTo": "0x017e7e58",
    "feeToSetter": "0xa2e74af6",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "name": "0x06fdde03",
    "owner": "0x8da5cb5b",
    "kLast": "0x7464fc3d",
    "factory": "0xc45a0155",
    "paused": "0x5c975abb",
    "getOwner": "0x893d20e8",
}

def word(addr):
    if isinstance(addr, int):
        return format(addr, "064x")
    return addr.lower().replace("0x", "").rjust(64, "0")

def words(*addrs):
    return "".join(word(a) for a in addrs)

def b32_to_addr(h):
    if not h or h == "0x":
        return None
    return "0x" + h[-40:]

def dec_str(h):
    if not h or h == "0x":
        return None
    b = bytes.fromhex(h[2:])
    if len(b) >= 64:
        # dynamic string
        try:
            off = int.from_bytes(b[0:32], "big")
            ln = int.from_bytes(b[off:off + 32], "big")
            return b[off + 32:off + 32 + ln].decode("utf-8", "replace")
        except Exception:
            return None
    return None

def hexint(h):
    if h is None or h == "0x":
        return None
    return int(h, 16)

def wdec(h):
    return hexint(h)
