#!/usr/bin/env python3
"""Query the TokenSwap STC/FAI pool reserves (read-only)."""
import json, urllib.request, sys

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
BF = "0x4ffcc98f43ce74668264a0cf6eebe42b"
STC = "0x1::STC::STC"
FAI = f"{BF}::FAI::FAI"

def getres(addr, typ):
    r = call("contract.get_resource", [addr, typ])
    return r.get("result", r.get("error"))

for label, fai in [("BFly FAI", FAI), ("other FAI (0xfe125d)", "0xfe125d419811297dfab03c61efec0bc9::FAI::FAI")]:
    pair = getres(DEX, f"{DEX}::TokenSwap::TokenSwapPair<{STC}, {fai}>")
    print(f"=== TokenSwapPair<STC, {label}> ===")
    print(json.dumps(pair, indent=1)[:1800])
    lp = getres(DEX, f"0x1::Token::TokenInfo<{DEX}::TokenSwap::LiquidityToken<{STC}, {fai}>>")
    print(f"--- LP TokenInfo {label} ---")
    print(json.dumps(lp, indent=1)[:600])
    print()
