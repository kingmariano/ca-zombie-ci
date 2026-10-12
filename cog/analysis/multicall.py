#!/usr/bin/env python3
"""Minimal Multicall3 aggregate3 helper (read-only) for Scroll."""
import json, time, urllib.request
from Crypto.Hash import keccak

MC = "0xca11bde05977b3631167028862be2a173976ca11"
RPCS = ["https://rpc.scroll.io", "https://scroll-rpc.publicnode.com", "https://scroll.drpc.org"]
_rr = [0]

def rpc(method, params, tries=4, timeout=30):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        u = RPCS[_rr[0] % len(RPCS)]; _rr[0] += 1
        try:
            req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json",
                                                                "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d: return d["result"]
            last = str(d.get("error"))
        except Exception as e:
            last = str(e)
        time.sleep(0.15 + 0.25 * i)
    raise RuntimeError(f"rpc failed {method}: {last}")

def sel(sig):
    k = keccak.new(digest_bits=256); k.update(sig.encode()); return "0x" + k.hexdigest()[:8]

SEL_AGG3 = sel("aggregate3((address,bool,bytes)[])")

def _w(x): return x.to_bytes(32, "big")

def aggregate3(calls, block="latest"):
    """calls: list of (target, calldata-hex). Returns list of (success, result-hex)."""
    n = len(calls)
    ptrs = []
    elems = []
    ptr = 32 * n
    for t, data in calls:
        raw = bytes.fromhex(data[2:] if data.startswith("0x") else data)
        pad = (-len(raw)) % 32
        ptrs.append(_w(ptr))
        elems.append(bytes.fromhex(t[2:].rjust(64, "0")) + _w(1) + _w(0x60)
                     + _w(len(raw)) + raw + b"\x00" * pad)
        ptr += 96 + 32 + len(raw) + pad
    arr = _w(n) + b"".join(ptrs) + b"".join(elems)
    cd = SEL_AGG3 + (_w(32) + arr).hex()
    r = rpc("eth_call", [{"to": MC, "data": cd}, block])
    raw = bytes.fromhex(r[2:])
    off0 = int.from_bytes(raw[0:32], "big")
    P = off0
    ln = int.from_bytes(raw[P:P+32], "big")
    elstart = P + 32  # pointers are relative to this
    out = []
    for i in range(ln):
        ptr_i = int.from_bytes(raw[elstart+i*32:elstart+(i+1)*32], "big")
        tsp = elstart + ptr_i
        ok = int.from_bytes(raw[tsp:tsp+32], "big") == 1
        boff = int.from_bytes(raw[tsp+32:tsp+64], "big")
        bsp = tsp + boff
        dln = int.from_bytes(raw[bsp:bsp+32], "big")
        out.append((ok, "0x" + raw[bsp+32:bsp+32+dln].hex()))
    return out

def read_uint(pair, selector, addr=None, block="latest"):
    data = selector + (addr[2:].rjust(64, "0") if addr else "")
    r = rpc("eth_call", [{"to": pair, "data": data}, block])
    return int(r, 16)

if __name__ == "__main__":
    pair = "0xaa230793737ddc517c2db9e42ca3a65178eda6d0"
    users = ["0x0000000000000000000000000000000000000001",
             "0x54a4c29196aad6fa77f9b4e35288e5234ac4f31a"]
    s = sel("user_borrow_part(address)")
    calls = [(pair, s + u[2:].rjust(64, "0")) for u in users]
    for ok, res in aggregate3(calls):
        print(ok, res, int(res, 16) if res != "0x" else None)
