#!/usr/bin/env python3
"""Keccak/eth_call helper + Grand Banks enumeration (read-only)."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
from bsc import rpc, rpc_batch, hexint
from Crypto.Hash import keccak

def sel(sig):
    k = keccak.new(digest_bits=256); k.update(sig.encode())
    return "0x" + k.hexdigest()[:8]

def keccakhex(data: bytes):
    k = keccak.new(digest_bits=256); k.update(data)
    return "0x" + k.hexdigest()

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def dec_uint(h):
    return int(h, 16) if h and h != "0x" else None

def dec_addr(h):
    if not h or len(h) < 42: return None
    return "0x" + h[-40:]

def dec_bool(h):
    return dec_uint(h) != 0

def call1(to, sig, args=""):
    return rpc("eth_call", [{"to": to, "data": sel(sig) + args}, "latest"])

if __name__ == "__main__":
    G1 = "0xd37ebaeb28c0a6c9a62d5c5c0119d464e28b367e"
    G2 = "0xee814f5b2bf700d2e843dc56835d28d095161dd9"
    TEAM = "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5"
    DEV = "0x18527a351db2435fa21db88cbb87d4155188b62b0"
    for label, t in [("G1", G1), ("G2", G2)]:
        for fn in ["name()", "symbol()", "decimals()", "totalSupply()", "owner()"]:
            try:
                r = call1(t, fn)
                v = r
                if fn in ("name()", "symbol()"):
                    # dynamic string decode
                    if r and r != "0x" and len(r) > 130:
                        off = int(r[2:66], 16); ln = int(r[66 + off*2:66 + off*2 + 64], 16)
                        v = bytes.fromhex(r[66 + off*2 + 64: 66 + off*2 + 64 + ln*2]).decode("utf-8", "replace")
                elif fn == "owner()":
                    v = dec_addr(r)
                elif fn == "totalSupply()":
                    v = dec_uint(r)
                print(label, fn, "=>", v)
            except Exception as e:
                print(label, fn, "ERR", str(e)[:120])
