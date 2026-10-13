#!/usr/bin/env python3
"""Probe on-chain quotes for Capybara pools (read-only eth_call)."""
import json
import subprocess
import sys
import urllib.request
import time

RPC = "https://public-en.node.kaia.io"

def sig(fn):
    r = subprocess.run(["cast", "sig", fn], capture_output=True, text=True)
    s = r.stdout.strip()
    if not s.startswith("0x"):
        raise RuntimeError(f"sig failed: {fn} {s}")
    return s[2:]

def enc(to, selector, args=None):
    data = "0x" + selector
    for a in args or []:
        if isinstance(a, int):
            data += f"{a:064x}"
        elif isinstance(a, str) and a.startswith("0x"):
            data += a[2:].lower().rjust(64, "0")
    return {"to": to, "data": data}

def call(c, block="latest"):
    last = None
    for rpc in [RPC, "https://kaia.drpc.org"]:
        for attempt in range(3):
            try:
                payload = [{"jsonrpc": "2.0", "id": 0, "method": "eth_call", "params": [c, block]}]
                req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "research"})
                r = json.loads(urllib.request.urlopen(req, timeout=40).read())
                return r[0].get("result") or ("ERR:" + str(r[0].get("error"))[:100])
            except Exception as e:
                last = e
                time.sleep(1.5)
    raise last

def dec_words(res):
    if not isinstance(res, str) or not res.startswith("0x"):
        return res
    b = bytes.fromhex(res[2:])
    return [int.from_bytes(b[i:i+32], "big") for i in range(0, len(b), 32)]

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "withdraw":
        pool, token, liq = sys.argv[2], sys.argv[3], int(sys.argv[4])
        r = call(enc(pool, sig("quotePotentialWithdraw(address,uint256)"), [token, liq]))
        print("quotePotentialWithdraw ->", dec_words(r))
    elif mode == "deposit":
        pool, token, amt = sys.argv[2], sys.argv[3], int(sys.argv[4])
        r = call(enc(pool, sig("quotePotentialDeposit(address,uint256)"), [token, amt]))
        print("quotePotentialDeposit ->", dec_words(r))
    elif mode == "swap":
        pool, frm, to, amt = sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
        r = call(enc(pool, sig("quotePotentialSwap(address,address,int256)"), [frm, to, amt]))
        print("quotePotentialSwap ->", dec_words(r))
    elif mode == "wdother":
        pool, frm, to, liq = sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
        r = call(enc(pool, sig("quotePotentialWithdrawFromOtherAsset(address,address,uint256)"), [frm, to, liq]))
        print("quotePotentialWithdrawFromOtherAsset ->", dec_words(r))
    elif mode == "xr":
        pool, token = sys.argv[2], sys.argv[3]
        r = call(enc(pool, sig("exchangeRate(address)"), [token]))
        print("exchangeRate ->", dec_words(r))
