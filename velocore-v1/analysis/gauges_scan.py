#!/usr/bin/env python3
"""Enumerate all Voter gauges: weights, claimable, isAlive, gauge state."""
import json, urllib.request, subprocess

RPC = "https://mainnet.era.zksync.io"
VOTER = "0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A"
VC = "0x85D84c774CF8e9fF85342684b0E795Df72A24908"

def selector(sig):
    return subprocess.run(["cast","sig",sig],capture_output=True,text=True).stdout.strip()

def rpc_batch(calls):
    payload=[]
    for i,(to,data) in enumerate(calls):
        payload.append({"jsonrpc":"2.0","id":i+1,"method":"eth_call","params":[{"from":"0x0000000000000000000000000000000000000BAD","to":to,"data":data,"gas":"0x600000"},"latest"]})
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req,timeout=60) as r: res=json.loads(r.read())
            break
        except Exception:
            if attempt==3: raise
            import time; time.sleep(2)
    if isinstance(res,dict): res=[res]
    out=[None]*len(calls)
    for item in res:
        out[item["id"]-1]=item.get("result")
    return out

def addr(a): return a[2:].lower().zfill(64)
def dec(h): return int(h,16) if h and h!="0x" else None

sel_pools = selector("pools(uint256)")
sel_gauges = selector("gauges(address)")
sel_w = selector("weights(address)")
sel_c = selector("claimable(address)")
sel_alive = selector("isAlive(address)")
sel_wpool = selector("weights(address)")

n = dec(rpc_batch([(VOTER, selector("length()"))])[0])
print("gauges:", n)
pools = []
for i in range(n):
    r = rpc_batch([(VOTER, sel_pools + hex(i)[2:].zfill(64))])[0]
    pools.append("0x"+r[-40:])
gauge_res = rpc_batch([(VOTER, sel_gauges + addr(p)) for p in pools])
gauges = ["0x"+r[-40:] if r else None for r in gauge_res]
w_res = rpc_batch([(VOTER, sel_w + addr(g)) for g in gauges])
c_res = rpc_batch([(VOTER, sel_c + addr(g)) for g in gauges])
a_res = rpc_batch([(VOTER, sel_alive + addr(g)) for g in gauges])
tw = dec(rpc_batch([(VOTER, selector("totalWeight()"))])[0])
print("totalWeight:", tw)
rows=[]
for p,g,w,c,a in zip(pools,gauges,w_res,c_res,a_res):
    rows.append({"pool":p,"gauge":g,"weight":dec(w),"claimable":dec(c),"alive":dec(a)})
rows.sort(key=lambda r:-(r["weight"] or 0))
tot_w=sum(r["weight"] or 0 for r in rows)
tot_c=sum(r["claimable"] or 0 for r in rows)
print("sum weights:", tot_w, "| sum claimable:", tot_c)
for r in rows[:20]:
    print(f"  {r['pool']} gauge={r['gauge']} weight={r['weight']} claimable={r['claimable']} alive={r['alive']}")
# gauge state for top-weighted gauge
g = rows[0]["gauge"]
print("== gauge", g)
for sig in ["totalSupply()","rewardRate()","periodFinish()","lastUpdateTime()","rewardToken()","rewards(address)","earned(address)","isForPair()","stake()","pool()","fees()","bribe()"]:
    args = addr("0x0000000000000000000000000000000000000BAD") if "(" in sig and sig.split("(")[1] != ")" else ""
    r = rpc_batch([(g, selector(sig)+args)])[0]
    print(f"  {sig:20} -> {r[:70] if r else 'REVERT'}")
json.dump({"totalWeight":tw,"rows":rows}, open("/home/heisenberg/CA/velocore-v1/analysis/gauges.json","w"), indent=1)
