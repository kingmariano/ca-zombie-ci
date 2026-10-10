#!/usr/bin/env python3
"""Starknet JSON-RPC helper (read-only). Keyless public endpoint by default.

Local use may set SN_RPC_URL to a keyed endpoint via env (NEVER write keys to files).
"""
import json, os, sys, time, urllib.request

try:
    from Crypto.Hash import keccak as _keccak

    def _keccak256(b: bytes) -> bytes:
        k = _keccak.new(digest_bits=256)
        k.update(b)
        return k.digest()
except Exception:  # no pycryptodome in CI
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from keccak_pure import keccak256 as _keccak256

RPC_LIST = [u for u in os.environ.get("SN_RPC_URL", "").split(",") if u] or \
           ["https://starknet-rpc.publicnode.com"]
RPC = RPC_LIST[0]
MASK = (1 << 250) - 1


def _redact(s):
    for u in RPC_LIST:
        if u and u in s:
            s = s.replace(u, "https://<rpc>")
    return s


def _rotate():
    global RPC
    i = RPC_LIST.index(RPC)
    RPC = RPC_LIST[(i + 1) % len(RPC_LIST)]
    return RPC


def sn_keccak(name: str) -> int:
    return int.from_bytes(_keccak256(name.encode()), "big") & MASK


def rpc(method, params, retries=5):
    global RPC
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(f"{method}: {d['error']}")
            return d["result"]
        except Exception as e:
            last = e
            if len(RPC_LIST) > 1:
                _rotate()
            time.sleep(1.2 * (i + 1))
    raise RuntimeError(_redact(f"{method} failed after {retries} retries: {last}"))


def _hexlist(vals):
    out = []
    for v in vals:
        out.append(hex(v) if isinstance(v, int) else v)
    return out


def call(to, func, calldata=None, block="latest"):
    sel = hex(sn_keccak(func))
    res = rpc("starknet_call", [{
        "contract_address": to if isinstance(to, str) else hex(to),
        "entry_point_selector": sel,
        "calldata": _hexlist(calldata or []),
    }, block])
    return [int(x, 16) for x in res]


def block_number():
    return rpc("starknet_blockNumber", [])


def class_hash_at(addr, block="latest"):
    return rpc("starknet_getClassHashAt", [block, addr])


def get_storage(addr, key, block="latest"):
    return rpc("starknet_getStorageAt", [addr, hex(key) if isinstance(key, int) else key, block])


def get_class(class_hash, block="latest"):
    return rpc("starknet_getClass", [block, class_hash])


def batch(reqs, retries=4):
    """reqs: list of (method, params). Returns list of results (Exception on error)."""
    global RPC
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(reqs)]
    body = json.dumps(payload).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"})
            with urllib.request.urlopen(req, timeout=90) as r:
                resp = json.load(r)
            out = [None] * len(reqs)
            if isinstance(resp, dict):  # whole-batch error
                err = RuntimeError(_redact(str(resp.get("error"))))
                return [err] * len(reqs)
            for item in resp:
                if "id" not in item or item["id"] is None:
                    continue
                out[item["id"]] = item["result"] if "result" in item else RuntimeError(_redact(str(item.get("error"))))
            for j in range(len(out)):
                if out[j] is None:
                    out[j] = RuntimeError("no response item")
            return out
        except Exception as e:
            last = e
            if len(RPC_LIST) > 1:
                _rotate()
            time.sleep(2 * (i + 1))
    raise RuntimeError(_redact(f"batch failed after {retries} retries: {last}"))


def call_batch(to, fns, block="latest"):
    """fns: list of (func, calldata). Returns list of raw results."""
    reqs = []
    for func, cd in fns:
        reqs.append(("starknet_call", [{
            "contract_address": to if isinstance(to, str) else hex(to),
            "entry_point_selector": hex(sn_keccak(func)),
            "calldata": _hexlist(cd or []),
        }, block]))
    res = batch(reqs)
    out = []
    for r in res:
        if isinstance(r, Exception):
            out.append(r)
        else:
            out.append([int(x, 16) for x in r])
    return out


def u256(vals, i=0):
    """Parse a Cairo Uint256 (low, high) pair starting at index i."""
    return vals[i] + (vals[i + 1] << 128)


def arr(vals):
    """Parse a Cairo array (len, ...items)."""
    n = vals[0]
    return vals[1:1 + n]


if __name__ == "__main__":
    print("rpc:", RPC)
    print("block:", block_number())
