#!/usr/bin/env python3
"""Proxy admins, beacon owners, service owners, gauge claimer, buffer percentages."""
import json, os, urllib.request
RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL")
def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"python-research"})
    with urllib.request.urlopen(req, timeout=60) as r: return json.load(r)["result"]
def batch(calls):
    out=[]
    for i in range(0,len(calls),5):
        chunk=calls[i:i+5]
        body=[{"jsonrpc":"2.0","id":i+j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        for attempt in range(5):
            try:
                req=urllib.request.Request(RPC,data=json.dumps(body).encode(),
                    headers={"Content-Type":"application/json","User-Agent":"python-research"})
                with urllib.request.urlopen(req,timeout=90) as r: res=json.load(r)
                break
            except Exception:
                if attempt==4: raise
                import time; time.sleep(2)
        if isinstance(res,dict): res=[res]
        m={x["id"]:x.get("result") for x in res}
        out += [m.get(i+j) for j in range(len(chunk))]
    return out
def u(w): return int(w,16) if w and w!="0x" else 0
def ad(w): return "0x"+w[-40:] if w and len(w)>=40 else None

ADMIN_SLOT="0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
IMPL_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
proxies={
 "tower":"0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7",
 "blackhole":"0x21777106355Ba506A31FF7984c0aE5C924deB77f",
 "manager":"0x7319662aD7D7ce2d1595073EA042B723F6d0dc48",
 "factory":"0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5",
 "distributor":"0x6B65525a40704a4c48d07c25b8D05654854DFEcD",
 "cvgSdt_gauge_sdCRV":"0x7f50786a0b15723d741727882ee99a0bf34e3466",
 "cvgSDT_token":"0x830614aE209FF9d8706d386fcdBc7a55206fcffC",
 "sdCRV_service":"0x2ff160bcadb485b5f048b9880e6f471af632060c",
 "cvgSdtStaking_svc":"0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933",
}
blk=int(rpc("eth_blockNumber",[]),16)
print("block",blk)
calls=[]
for k,a in proxies.items():
    calls.append(("eth_getStorageAt",[a,ADMIN_SLOT,"latest"]))
res=batch(calls)
for (k,a),r in zip(proxies.items(),res):
    print(f"proxy.admin {k:22s} {a} => {ad(r)}")
# beacon owner
fac="0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5"
sel={"beaconSdStaking":"0x06d1c1d5","owner":"0x8da5cb5b"}
# get selector values via cast offline; assume passed in

# beacon owners + service owners + initialized + gauge claimer + buffer pct
print("--- follow-ups ---")
BEACON=""
r=rpc("eth_call",[{"to":fac,"data":"0xce4c1f60"},"latest"])
beacon=ad(r); print("beaconSdStaking:",beacon)
r=rpc("eth_call",[{"to":beacon,"data":"0x8da5cb5b"},"latest"])
print("beacon.owner:",ad(r))
r=rpc("eth_call",[{"to":fac,"data":"0x18e0bd0b"},"latest"])
print("beaconBuffer:",ad(r))
svc_state=json.load(open("state_positions.json"))["positions"]
calls=[]
for p in svc_state:
    calls.append(("eth_call",[{"to":p["staking"],"data":"0x8da5cb5b"},"latest"]))     # owner
    calls.append(("eth_call",[{"to":p["staking"],"data":"0x158ef93e"},"latest"]))     # initialized()
    calls.append(("eth_call",[{"to":p["cvgSdt"],"data":"0xd379be23"},"latest"]))      # claimer
res=batch(calls)
owners=set(); uninits=[]
for i,p in enumerate(svc_state):
    o=ad(res[i*3]); ini=u(res[i*3+1]); cl=ad(res[i*3+2])
    owners.add(o)
    if ini==0: uninits.append(p["staking"])
    p["service_owner"]=o; p["service_initialized"]=ini; p["gauge_claimer"]=cl
print("distinct service owners:",owners)
print("uninitialized services:",uninits)
claimers=set(p["gauge_claimer"] for p in svc_state)
print("distinct gauge claimers:",claimers)
json.dump(svc_state,open("service_state.json","w"),indent=1)
# buffer processorRewardsPercentage
calls=[("eth_call",[{"to":p["staking"],"data":"0x6c5a4944"},"latest"]) for p in svc_state]  # buffer()
res=batch(calls)
bufs=[ad(x) for x in res]
print("distinct buffers:",len(set(bufs)))
calls=[("eth_call",[{"to":b,"data":"0x772582ef"},"latest"]) for b in bufs]
res=batch(calls)
pcts={}
for b,x in zip(bufs,res):
    pcts.setdefault(b,u(x))
print("buffer processorRewardsPercentage:",pcts)
