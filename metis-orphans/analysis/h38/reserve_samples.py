#!/usr/bin/env python3
"""Sample reserves + totalSupply + k at key blocks via archive RPC."""
import json, sys, urllib.request

RPC = "https://andromeda.metis.io/?owner=1088"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
       "Content-Type": "application/json"}

def rpc(method, params, tries=5):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers=HDR)
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:
            sys.stderr.write(f"retry {i}: {e}\n")
            import time; time.sleep(2 * (i + 1))
    raise RuntimeError("failed")

PAIRS = {
    "A": "0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1",
    "C": "0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091",
}
# (block, label)
SAMPLES = [
    (21312, "genesis"),
    (100000, "2022-02-early"),
    (253268, "2022-02-08 after first big burns"),
    (680691, "2022-03-01"),
    (807900, "2022-03-10"),
    (1902534, "2022-03-26 last big burn"),
    (2477360, "2022-05-01"),
    (5000000, "~2022-08"),
    (10000000, "~2023-02"),
    (15000000, "~2023-10"),
    (20000000, "~2024-06"),
    (23238721, "now"),
]

def call(to, sig, blk, extra=None):
    data = sig
    params = [{"to": to, "data": data}, hex(blk)]
    out = rpc("eth_call", params)
    return out

# selectors
SEL_GETRESERVES = "0x0902f1ac"
SEL_TOTALSUPPLY = "0x18160ddd"

res = {}
for name, addr in PAIRS.items():
    rows = []
    for blk, label in SAMPLES:
        try:
            r = call(addr, SEL_GETRESERVES, blk)
            t = call(addr, SEL_TOTALSUPPLY, blk)
            rb = rpc("eth_getBlockByNumber", [hex(blk), False])
            r0 = int(r[2:66], 16); r1 = int(r[66:130], 16)
            ts = int(rb["timestamp"], 16)
            sup = int(t, 16)
            rows.append({"block": blk, "label": label, "ts": ts, "reserve0": r0, "reserve1": r1, "totalSupply": sup})
            print(f"{name} blk={blk:>9} ts={ts} r0={r0} r1={r1} sup={sup/1e18:.9f}")
        except Exception as e:
            print(f"{name} blk={blk} FAILED {e}")
    res[name] = rows
json.dump(res, open("raw/reserve_samples.json", "w"), indent=1)
