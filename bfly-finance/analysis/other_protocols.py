#!/usr/bin/env python3
"""Analyze the WEN LendingPoolV2 (0xbf60b0...) and the second BFly deployment (0xfe125d...)."""
import json, re, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())
def view(fn, args=[], ta=[]):
    r = call("contract.call_v2", [{"function_id": fn, "args": args, "type_args": ta}])
    return r.get("result", r.get("error"))

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

for label, addr in [("WEN LendingPoolV2", "0xbf60b00855c92fe725296a436101c8c6"),
                    ("second BFly", "0xfe125d419811297dfab03c61efec0bc9")]:
    print(f"################ {label} {addr}")
    codes = call("state.list_code", [addr])["result"]["codes"]
    # candidate functions per module
    for mod in sorted(codes):
        ids = strings_of(codes[mod]["code"])
        cands = [s for s in ids if re.match(r'^[a-z][a-z0-9_]*$', s) and len(s) >= 3]
        seen = set(); cands = [c for c in cands if not (c in seen or seen.add(c))]
        def resolve(fn):
            try:
                rr = call("contract.resolve_function", [f"{addr}::{mod}::{fn}"])
                if "result" in rr:
                    res = rr["result"]
                    return (fn, [str(a["type_tag"]) for a in res["args"]], res["returns"])
            except Exception:
                pass
            return None
        found = []
        with ThreadPoolExecutor(max_workers=8) as ex:
            for res in ex.map(resolve, cands):
                if res: found.append(res)
        if found:
            print(f"== {mod}")
            for fn, args, rets in found:
                print(f"   {fn}({', '.join(args)}) -> {rets}")
    res = call("state.list_resource", [addr])["result"]["resources"]
    print("--- resources ---")
    for k in sorted(res):
        raw = res[k]["raw"]
        print(f"   {k} = {raw[:100]}")
    print()
