#!/usr/bin/env python3
"""Live balances of the Convergence Fi custody chain + reward pools. Read-only.
Outputs analysis/live_balances.json (chain data only)."""
import json, os, sys, urllib.request

RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL")
BLACKHOLE = "0x21777106355Ba506A31FF7984c0aE5C924deB77f"
DISTRIBUTOR = "0x6B65525a40704a4c48d07c25b8D05654854DFEcD"
FEE_COLLECTOR = None  # read from tower
TOWER = "0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7"

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"python-research"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["result"]

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        body = [{"jsonrpc":"2.0","id":i+j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        req = urllib.request.Request(RPC, data=json.dumps(body).encode(),
                                     headers={"Content-Type":"application/json","User-Agent":"python-research"})
        with urllib.request.urlopen(req, timeout=120) as r:
            res = json.load(r)
        if isinstance(res, dict): res=[res]
        m = {x["id"]: x.get("result") for x in res}
        out += [m.get(i+j) for j in range(len(chunk))]
    return out

def pad_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def u(w): return int(w,16) if w and w!="0x" else 0
def ad(w): return "0x"+w[-40:] if w and len(w)>=40 else None

SEL = {
 "balanceOf": "0x70a08231",
 "totalSupply": "0x18160ddd",
 "stakingAsset": "0x1b4e0c47",
 "cycleInfo": "0x44f79609",
 "sdtFeeCollector": "0x06ee5ed2",
 "claimer": "0xd379be23",
 "processorRewardsPercentage": "0x772582ef",
}
# selectors verified via cast sig in analysis/selectors.txt (written by shell step)

blk = int(rpc("eth_blockNumber",[]),16)
state = json.load(open("state_positions.json"))
positions = state["positions"]

# 1) balanceOf(blackhole) of every staking asset + totalSupply
calls=[]
for p in positions:
    t = p["cvgSdt"]
    calls.append(("eth_call",[{"to":t,"data":SEL["balanceOf"]+pad_addr(BLACKHOLE)},"latest"]))
    calls.append(("eth_call",[{"to":t,"data":SEL["totalSupply"]},"latest"]))
res = batch(calls)
for i,p in enumerate(positions):
    p["blackhole_balance"] = u(res[i*2]) if res[i*2] else None
    p["asset_totalSupply"] = u(res[i*2+1]) if res[i*2+1] else None

out = {"block": blk, "positions": positions}
json.dump(out, open("live_balances.json","w"), indent=1)
print("block", blk)
tot=0
for p in positions:
    a=p["actualTotal"]; b=p["blackhole_balance"] or 0
    print(f'{p["name"][:30]:32s} asset={p["cvgSdt"][:10]} actualTotal={a:>26} blackhole={b:>26} match={"Y" if b>=a else "N"} supply={p["asset_totalSupply"]}')
