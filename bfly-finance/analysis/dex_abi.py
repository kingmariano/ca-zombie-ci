#!/usr/bin/env python3
"""Enumerate TokenSwap DEX functions and simulate swaps (read-only)."""
import json, re, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=45):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
r = call("state.list_code", [DEX])
mods = r["result"]["codes"]
print("modules:", len(mods))
for name in sorted(mods):
    print("  ", name)
json.dump({k: v["code"] for k, v in mods.items()}, open("dex_modules.json", "w"))

def strings_of(hexcode):
    b = bytes.fromhex(hexcode[2:] if hexcode.startswith("0x") else hexcode)
    out, cur = [], b""
    for byte in b:
        if 32 <= byte < 127: cur += bytes([byte])
        else:
            if len(cur) >= 3: out.append(cur.decode())
            cur = b""
    if len(cur) >= 3: out.append(cur.decode())
    return out

focus = ["TokenSwapRouter", "TokenSwap", "TokenSwapLibrary", "TokenSwapConfig"]
for mod in focus:
    if mod not in mods: continue
    ids = strings_of(mods[mod]["code"])
    cands = [s for s in ids if re.match(r'^[a-z][a-z0-9_]*$', s) and len(s) >= 3]
    seen=set(); cands=[c for c in cands if not (c in seen or seen.add(c))]
    def resolve(fn):
        try:
            rr = call("contract.resolve_function", [f"{DEX}::{mod}::{fn}"])
            if "result" in rr:
                res = rr["result"]
                return (fn, [a["type_tag"] for a in res["args"]], res["returns"])
        except Exception:
            pass
        return None
    print(f"\n== {mod} public ABI ==")
    with ThreadPoolExecutor(max_workers=8) as ex:
        for res in ex.map(resolve, cands):
            if res:
                fn, args, rets = res
                print(f"   {fn}({', '.join(str(a) for a in args)}) -> {rets}")
