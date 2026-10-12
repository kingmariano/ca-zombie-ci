#!/usr/bin/env python3
"""Enumerate v1 Trading positions (0xA55Eee92) and v2 Trading positions (from event keys)."""
import json, os, subprocess, urllib.request, time

RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

def batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": c[0], "data": c[1]}, "latest"]} for i, c in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for _ in range(4):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=60))
            out = [None] * len(calls)
            for item in d:
                out[item["id"]] = item.get("result")
            return out
        except Exception:
            time.sleep(2)
    return [None] * len(calls)

def enc_arr(vals):
    return hex(0x20)[2:].rjust(64, "0") + hex(len(vals))[2:].rjust(64, "0") + \
           "".join(hex(v)[2:].rjust(64, "0") for v in vals)

def dec_arr_of_tuple(hexstr, types):
    b = bytes.fromhex(hexstr[2:])
    off = int.from_bytes(b[0:32], "big")
    n = int.from_bytes(b[off:off+32], "big")
    sz = len(types) * 32
    out = []
    for i in range(n):
        base = off + 32 + i * sz
        vals = [int.from_bytes(b[base + j*32: base + (j+1)*32], "big") for j in range(len(types))]
        out.append(vals)
    return out

# ---- v1 positions ----
V1 = "0xA55Eee92a46A50A4C65908F28A0BE966D3e71633"
SEL_POS_V1 = sel("getPositions(uint256[])")
TYPES_V1 = ["uint40", "uint24", "uint64", "uint64", "uint64", "address", "uint88", "bool"]
allpos = []
for start in range(1, 2098, 400):
    ids = list(range(start, min(start+400, 2098)))
    r = batch([(V1, SEL_POS_V1 + enc_arr(ids))])[0]
    if not r:
        print("v1 chunk fail", start); continue
    arr = dec_arr_of_tuple(r, TYPES_V1)
    for i, p in enumerate(arr):
        allpos.append({"id": ids[i], "closeOrderId": p[0], "productId": p[1], "leverage": p[2],
                       "price": p[3], "margin": p[4], "owner": "0x"+hex(p[5])[2:].rjust(40,"0"),
                       "timestamp": p[6], "isLong": bool(p[7])})
    time.sleep(0.2)
open_pos = [p for p in allpos if p["margin"] > 0]
print("V1 positions with margin>0:", len(open_pos), "sum margin(8dec):", sum(p["margin"] for p in open_pos))
print("  settling (price==0):", sum(1 for p in open_pos if p["price"] == 0),
      "sum:", sum(p["margin"] for p in open_pos if p["price"] == 0))
print("  settled (price>0):", sum(1 for p in open_pos if p["price"] > 0),
      "sum:", sum(p["margin"] for p in open_pos if p["price"] > 0))
json.dump(allpos, open(os.path.join(outdir, "v1-positions.json"), "w"), indent=1)
for p in sorted(open_pos, key=lambda x: -x["margin"])[:15]:
    print("   ", p)
