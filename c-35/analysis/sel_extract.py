#!/usr/bin/env python3
"""Extract PUSH4 selectors from live bytecode (eth_getCode). Read-only, light.
Usage: python3 sel_extract.py 0xaddr [--json out.json]
"""
import json, os, sys, urllib.request

ENDPOINTS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth"]


def rpc(method, params):
    for url in ENDPOINTS:
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=25) as r:
                d = json.loads(r.read())
            if "result" in d:
                return d["result"]
        except Exception:
            continue
    raise RuntimeError("no rpc")


def extract(code_hex):
    code = bytes.fromhex(code_hex[2:])
    sels = set()
    i = 0
    while i < len(code):
        op = code[i]
        if op == 0x63 and i + 4 < len(code):  # PUSH4
            sels.add(code[i + 1:i + 5].hex())
            i += 5
        else:
            i += 1
    return sorted(sels)


if __name__ == "__main__":
    addr = sys.argv[1]
    code = rpc("eth_getCode", [addr, "latest"])
    sels = extract(code)
    out = {"address": addr, "code_size": len(code) // 2 - 1, "selectors": sels}
    print(json.dumps(out, indent=1))
