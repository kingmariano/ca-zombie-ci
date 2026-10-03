#!/usr/bin/env python3
"""Read-only: batch eth_getBalance for seg-C addrs at latest block via public RPC."""
import json, urllib.request, sys

RPC = "https://ethereum-rpc.publicnode.com"
addrs = json.load(open("/home/heisenberg/CA/c-36/analysis/seg_C_addrs.json"))

reqs = [{"jsonrpc":"2.0","id":i,"method":"eth_getBalance","params":[a,"latest"]} for i,a in enumerate(addrs)]
data = json.dumps(reqs).encode()
r = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
resp = json.load(urllib.request.urlopen(r, timeout=60))
out = {}
for item in resp:
    out[addrs[item["id"]]] = int(item["result"],16)/1e18
# block
r2 = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
bn = int(json.load(urllib.request.urlopen(r2, timeout=30))["result"],16)
json.dump({"block":bn,"balances":out}, open("/home/heisenberg/CA/c-36/analysis/seg-C/raw/live_balances.json","w"), indent=1)
for a in addrs:
    print(f"{a} {out[a]:18.8f}")
print("block", bn)
