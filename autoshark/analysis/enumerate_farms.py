#!/usr/bin/env python3
"""Enumerate MasterOcean/MasterSquid farm pools + staked balances (BSC read-only)."""
import json, requests
RPC = "https://bsc-rpc.publicnode.com"
FARMS = {
    "MasterOcean": "0x8857af8205f224870dea119e2c75af386efb192a",
    "MasterSquid": "0x86a47ddd4c6522251d6a5a5800f3f24c03332cb4",
}
SEL = {"poolLength": "0x081e3eda", "poolInfo": "0x1526fe27", "balanceOf": "0x70a08231",
       "lpToken": "0x78ed5d1f", "allocPoint": "0x0b6a2cba", "totalAllocPoint": "0x17caf6f1"}

def enc_uint(v): return hex(v)[2:].rjust(64, "0")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

def call(to, data):
    r = requests.post(RPC, json={"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                                 "params": [{"to": to, "data": data}, "latest"]}, timeout=30).json()
    return r.get("result")

def uint(h): return int(h, 16) if h and h != "0x" else None

out = {}
for name, farm in FARMS.items():
    n = uint(call(farm, SEL["poolLength"]))
    print(name, "pools:", n)
    pools = []
    for i in range(n):
        pi = call(farm, SEL["poolInfo"] + enc_uint(i))
        if not pi or len(pi) < 2 + 64 * 4:
            pools.append({"pid": i, "raw": pi})
            continue
        b = bytes.fromhex(pi[2:])
        lp = "0x" + b[0:32].hex()[-40:]
        alloc = int.from_bytes(b[32:64], "big")
        # poolInfo layouts vary; assume (lpToken, allocPoint, ...)
        pools.append({"pid": i, "lpToken": lp, "allocPoint": alloc})
    # staked balances
    for p in pools:
        if p.get("lpToken"):
            bal = call(p["lpToken"], SEL["balanceOf"] + enc_addr(farm))
            p["farmLPBalance"] = uint(bal)
    out[name] = {"address": farm, "poolLength": n, "pools": pools}
    nonzero = [p for p in pools if (p.get("farmLPBalance") or 0) > 0]
    print(f"  pools with staked LP > 0: {len(nonzero)}")
    for p in nonzero[:50]:
        print(f"   pid={p['pid']} lp={p['lpToken']} staked_raw={p['farmLPBalance']} alloc={p['allocPoint']}")

json.dump(out, open("/home/heisenberg/CA/autoshark/analysis/farm_pools.json", "w"), indent=1)
print("saved")
