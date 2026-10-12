#!/usr/bin/env python3
"""Quantify LP -> PUSD/IRON/xUSD extraction from IronSwap meta-pools,
and check the external markets' depth. Public RPC only."""
import subprocess, json, urllib.request

P = "https://polygon-bor-rpc.publicnode.com"

def call(to, sig, args=()):
    out = subprocess.run(["cast", "call", to, sig, *map(str, args), "--rpc-url", P],
                         capture_output=True, text=True)
    t = out.stdout.strip()
    if not t:
        return None, out.stderr.strip()[:100]
    return t, None

def quote(pool, i, j, amt_wei):
    t, err = call(pool, "calculateSwap(uint8,uint8,uint256)(uint256)", (i, j, amt_wei))
    return int(t.split()[0]) if t else None

ISPUSD = "0x4a783cd1b4543559ece45db47e07e0cb59e55c09"
ISIRON = "0xCaEb732167aF742032D13A9e76881026f91Cd087"
ISXUSD = "0xe440ccc13e6f273c110cf3cf4087c23a66b8e872"

print("=== ISPUSD: LP(idx0) in -> PUSD(idx1) out")
for amt in [1, 2, 5, 9, 20, 50, 100]:
    dy = quote(ISPUSD, 0, 1, amt * 10**18)
    print(f"  LP in {amt:>4} -> PUSD out {dy/1e18:>10.3f} | market value @0.1317: ${dy/1e18*0.1317:8.2f} | LP cost ${amt*1.0108:8.2f}")

print("=== ISIRON: LP(idx0) in -> IRON(idx1) out")
for amt in [1, 5, 10, 30, 61, 120]:
    dy = quote(ISIRON, 0, 1, amt * 10**18)
    print(f"  LP in {amt:>4} -> IRON out {dy/1e18:>12.0f} | market value @0.0000738: ${dy/1e18*0.0000738:8.2f} | LP cost ${amt*1.0108:8.2f}")

print("=== ISXUSD: LP(idx0) in -> xUSD(idx1) out")
for amt in [1, 5, 25, 100]:
    dy = quote(ISXUSD, 0, 1, amt * 10**18)
    print(f"  LP in {amt:>4} -> xUSD out {dy/1e18:>8.3f} | market value @1.05: ${dy/1e18*1.05:8.2f} | LP cost ${amt*1.0108:8.2f}")
