#!/usr/bin/env python3
"""Read-only helper for Prom chain via public keyless RPC. No secrets."""
import json, sys, urllib.request

RPC = "https://rpc.prom.io"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"}

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        out = json.loads(r.read())
    if "error" in out:
        raise RuntimeError(f"{method} {params}: {out['error']}")
    return out.get("result")

def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])

def block_number():
    return int(rpc("eth_blockNumber", []), 16)

# --- ABI helpers ---
def sel(sig):
    import hashlib
    return "0x" + hashlib.sha3_256(sig.encode()).hexdigest()[:8] if False else None

# keccak via eth hashing not available in stdlib; use precomputed selectors
SEL = {
    "allPairsLength()": "0x574f2ba3",
    "allPairs(uint256)": "0x1e3dd18b",
    "getPair(address,address)": "0xe6a43905",
    "feeTo()": "0x017e7e58",
    "feeToSetter()": "0x094b7415",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "totalSupply()": "0x18160ddd",
    "balanceOf(address)": "0x70a08231",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "kLast()": "0x7464fc3d",
    "owner()": "0x8da5cb5b",
    "allowance(address,address)": "0xdd62ed3e",
    "DOMAIN_SEPARATOR()": "0x3644e515",
}

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def enc_uint(x):
    return hex(int(x))[2:].rjust(64, "0")

def dec_uint(h):
    return int(h, 16) if h and h != "0x" else 0

def dec_addr(h):
    return "0x" + h[-40:]

def read_str(h):
    if h in (None, "0x"):
        return ""
    b = bytes.fromhex(h[2:])
    if len(b) < 64:
        return ""
    off = int.from_bytes(b[:32], "big")
    if off + 32 > len(b):
        return ""
    ln = int.from_bytes(b[off:off+32], "big")
    return b[off+32:off+32+ln].decode("utf-8", "replace").strip("\x00")

def call_uint(to, sig, args=(), block="latest"):
    data = SEL[sig] + "".join(enc_addr(a) if isinstance(a, str) and a.startswith("0x") else enc_uint(a) for a in args)
    return dec_uint(call(to, data, block))

def call_addr(to, sig, args=(), block="latest"):
    data = SEL[sig] + "".join(enc_addr(a) if isinstance(a, str) and a.startswith("0x") else enc_uint(a) for a in args)
    return dec_addr(call(to, data, block))

def call_str(to, sig, args=(), block="latest"):
    data = SEL[sig] + "".join(enc_addr(a) if isinstance(a, str) and a.startswith("0x") else enc_uint(a) for a in args)
    return read_str(call(to, data, block))

def reserves(pair, block="latest"):
    h = call(pair, SEL["getReserves()"], block)
    b = bytes.fromhex(h[2:])
    r0 = int.from_bytes(b[0:32], "big")
    r1 = int.from_bytes(b[32:64], "big")
    ts = int.from_bytes(b[64:96], "big")
    return r0, r1, ts

def bal(token, who, block="latest"):
    return call_uint(token, "balanceOf(address)", [who], block)

def token_meta(token, block="latest"):
    return {
        "address": token,
        "symbol": call_str(token, "symbol()", block=block),
        "name": call_str(token, "name()", block=block),
        "decimals": call_uint(token, "decimals()", block=block),
    }

if __name__ == "__main__":
    print("latest block:", block_number())
    if len(sys.argv) > 1 and sys.argv[1] == "meta":
        for t in sys.argv[2:]:
            print(token_meta(t))
