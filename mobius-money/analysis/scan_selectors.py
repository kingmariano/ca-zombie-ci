#!/usr/bin/env python3
"""Scan deployed bytecode of a Celo contract for PUSH4 selector constants.
Usage: python3 scan_selectors.py <address> [--code <hex>]
Output: list of '0xdeadbeef' selectors + count.
"""
import sys, json, urllib.request, re

RPC = "https://forno.celo.org"


def get_code(addr):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getCode", "params": [addr, "latest"]}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                          "User-Agent": "Mozilla/5.0 (research)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())["result"]


def scan(code):
    h = code[2:] if code.startswith("0x") else code
    sels = {}
    i = 0
    n = len(h)
    while i < n - 8:
        op = h[i:i + 2]
        if op == "63":  # PUSH4
            sel = "0x" + h[i + 2:i + 10]
            sels[sel] = sels.get(sel, 0) + 1
            i += 10
        elif op in ("60", "61", "62", "64", "65", "66", "67"):  # PUSH1..PUSH8 (data)
            i += 2 + 2 * int(op, 16) - 2 + 0
            i = i  # placeholder
        else:
            i += 2
    return sels


def scan2(code):
    """Robust: walk EVM opcodes handling PUSH1..PUSH32."""
    h = code[2:] if code.startswith("0x") else code
    out = {}
    i = 0
    while i < len(h) - 1:
        op = int(h[i:i + 2], 16)
        if op == 0x63 and i + 10 <= len(h):  # PUSH4
            out["0x" + h[i + 2:i + 10]] = out.get("0x" + h[i + 2:i + 10], 0) + 1
            i += 10
        elif 0x60 <= op <= 0x7f:
            i += 2 * (op - 0x5f) + 2
        else:
            i += 2
    return out


if __name__ == "__main__":
    addr = sys.argv[1]
    code = get_code(addr)
    sels = scan2(code)
    print(f"{addr} code bytes={len(code)//2-1} selectors={len(sels)}")
    for s, c in sorted(sels.items()):
        print(s, c)
