#!/usr/bin/env python3
"""Read current Lybra positions for all borrowers (JSON-RPC batch, read-only)."""
import json, urllib.request, time, sys

RPC = "https://ethereum-rpc.publicnode.com"
LYBRA = "0x97de57eC338AB5d51557DA3434828C5DbFaDA371"
SEL_DEP = "0x" + "8f9bbf1a"  # placeholder, computed below
import hashlib

def sel(sig):
    k = hashlib.sha3_256(sig.encode()).hexdigest()[:8]  # NOT keccak; use known values
    return k

# known selectors via cast
SEL_DEPOSITED = __import__("subprocess").run(
    ["cast", "sig", "depositedEther(address)"], capture_output=True, text=True).stdout.strip()
SEL_BORROWED = __import__("subprocess").run(
    ["cast", "sig", "getBorrowedOf(address)"], capture_output=True, text=True).stdout.strip()
SEL_BALANCE = "0x70a08231"  # balanceOf(address)
SEL_ALLOWANCE = "0xdd62ed3e"  # allowance(address,address)

import sys
BLOCK = ("0x%x" % int(sys.argv[1])) if len(sys.argv)>1 and sys.argv[1] != "latest" else "latest"
print("selectors:", SEL_DEPOSITED, SEL_BORROWED, "block", BLOCK)

users = json.load(open("analysis/borrowers.json"))

def call_data(selector, user):
    return selector + "0"*24 + user[2:].lower()

def batch(calls):
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, BLOCK]})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                res = json.loads(r.read())
            out = {}
            for item in res:
                out[item["id"]] = item.get("result")
            return out
        except Exception as e:
            print("batch retry", attempt, e, file=sys.stderr)
            time.sleep(2 + attempt * 3)
    raise RuntimeError("batch failed")

results = {}
B = 60
for start in range(0, len(users), B):
    chunk = users[start:start+B]
    calls = []
    meta = []
    for u in chunk:
        calls.append((LYBRA, call_data(SEL_DEPOSITED, u))); meta.append((u, "dep"))
        calls.append((LYBRA, call_data(SEL_BORROWED, u))); meta.append((u, "bor"))
        calls.append((LYBRA, call_data(SEL_BALANCE, u))); meta.append((u, "eusd"))
        calls.append((LYBRA, call_data(SEL_ALLOWANCE, u))); meta.append((u, "allow"))  # allowance(u, LYBRA)
    # fix allowance call data: allowance(user, lybra)
    calls = []
    meta = []
    for u in chunk:
        calls.append((LYBRA, call_data(SEL_DEPOSITED, u))); meta.append((u, "dep"))
        calls.append((LYBRA, call_data(SEL_BORROWED, u))); meta.append((u, "bor"))
        calls.append((LYBRA, call_data(SEL_BALANCE, u))); meta.append((u, "eusd"))
        calls.append((LYBRA, SEL_ALLOWANCE + "0"*24 + u[2:] + "0"*24 + LYBRA[2:].lower())); meta.append((u, "allow"))
    out = batch(calls)
    for i, (u, kind) in enumerate(meta):
        r = out.get(i)
        v = int(r, 16) if r and r != "0x" else 0
        results.setdefault(u, {})[kind] = v
    print(f"{start+len(chunk)}/{len(users)}", flush=True)

import os
out=sys.argv[2] if len(sys.argv)>2 else "analysis/positions_raw.json"
json.dump(results, open(out, "w"))
print("saved", out)
