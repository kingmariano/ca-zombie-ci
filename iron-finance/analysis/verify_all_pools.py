#!/usr/bin/env python3
"""Verify each deployed pool's runtime code vs local artifact.
Strips metadata properly (last 2 bytes = metadata length), substitutes the
linked library address placeholder. Read-only, public RPCs."""
import json, subprocess, re, sys

RPC = {"polygon": "https://polygon-bor-rpc.publicnode.com",
       "avalanche": "https://avalanche-c-chain-rpc.publicnode.com",
       "fantom": "https://rpcapi.fantom.network"}
POOLS = {
    "polygon:is3usd": ("0x837503e8a8753ae17fb8c8151b8e6f586defcb57", "polygon"),
    "polygon:ispusd": ("0x4a783cd1b4543559ece45db47e07e0cb59e55c09", "polygon"),
    "polygon:isxusd": ("0xe440ccc13e6f273c110cf3cf4087c23a66b8e872", "polygon"),
    "polygon:isiron": ("0xCaEb732167aF742032D13A9e76881026f91Cd087", "polygon"),
    "avalanche:is3usd": ("0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523", "avalanche"),
    "fantom:is3usd": ("0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523", "fantom"),
}

def cast_code(addr, rpc):
    return subprocess.run(["cast", "code", addr, "--rpc-url", rpc],
                          capture_output=True, text=True, timeout=60).stdout.strip()

def strip_metadata(h):
    b = bytes.fromhex(h.replace("0x", ""))
    if len(b) < 4: return b
    mlen = int.from_bytes(b[-2:], "big")
    if mlen + 2 <= len(b):
        return b[:-(mlen + 2)]
    return b

art = json.load(open("poc/out/IronSwap.sol/IronSwap.json"))
local = art["deployedBytecode"]["object"].replace("0x", "")
local = local.replace("__$8ae8008f7b455dec14e448ff86fd3fb81a$__", "7e812ca56574ed578640daedfe2cb3ef93937ee9")
lcode = strip_metadata(local)
print(f"local code bytes: {len(lcode)}")

for name, (addr, chain) in POOLS.items():
    try:
        code = cast_code(addr, RPC[chain])
        ocode = strip_metadata(code)
        total = len(bytes.fromhex(code.replace('0x','')))
        match = lcode == ocode
        if not match:
            # first diff
            i = 0
            n = min(len(lcode), len(ocode))
            while i < n and lcode[i] == ocode[i]: i += 1
            note = f"DIFFER at byte {i} (local {len(lcode)}B vs onchain {len(ocode)}B)"
        else:
            note = "MATCH"
        print(f"{name:22s} total={total:6d} code={len(ocode):6d}  {note}")
    except Exception as e:
        print(f"{name:22s} ERROR {e}")
