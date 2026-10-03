#!/usr/bin/env python3
"""Exact on-chain swap quote for the STC->FAI arb (read-only view call)."""
import json, urllib.request

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())
def view(fn, args=[], ta=[]):
    r = call("contract.call_v2", [{"function_id": fn, "args": args, "type_args": ta}])
    return r.get("result", r.get("error"))

DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
STC = "0x1::STC::STC"
FAI = "0x4ffcc98f43ce74668264a0cf6eebe42b::FAI::FAI"
X = 410813790911242
Y = 21413902183198

def q(amount_in):
    return view(f"{DEX}::TokenSwapLibrary::get_amount_out",
                [f"{amount_in}u128", f"{X}u128", f"{Y}u128", "3", "1000"])

for amt in [10_000_00000000, 100_000_00000000, 421_022_514000000, 577_900_00000000]:
    out = q(amt)
    fai = out[0] if isinstance(out, list) else None
    seize = (fai * 10**8) // (10000 * 90) if fai else 0
    print(f"swap {amt/1e9:>14,.3f} STC -> {fai/1e9 if fai else 0:>12,.4f} FAI -> seize {seize/1e9:>14,.3f} STC -> net {(seize-amt)/1e9:>12,.3f} STC")

# python formula check
def fai_out(dx): return (dx * 997 * Y) // (X * 1000 + dx * 997)
print("\npython check for 421022.514 STC:", fai_out(421022514000000), "vs on-chain above")
