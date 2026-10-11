#!/usr/bin/env python3
"""CI evidence dump: Convergence Fi live state at the CI fork block.
Read-only; prints chain data only. No RPC URLs / secrets in output."""
import json, os, sys, urllib.request

def pick_rpc():
    for k in ("FORK_RPC_URL","BLOCKPI_RPC_URL","NODEREAL_ETH_RPC_URL","RPC_URL"):
        u=os.environ.get(k)
        if u: return u
    return "https://ethereum-rpc.publicnode.com"

RPC=pick_rpc()
TOWER="0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7"
BLACKHOLE="0x21777106355Ba506A31FF7984c0aE5C924deB77f"
MANAGER="0x7319662aD7D7ce2d1595073EA042B723F6d0dc48"
DIST="0x6B65525a40704a4c48d07c25b8D05654854DFEcD"
SDT="0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F"
CVGSDT="0x830614aE209FF9d8706d386fcdBc7a55206fcffC"
CVGSDT_SVC="0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933"

def rpc(method,params):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"python-research"})
    with urllib.request.urlopen(req,timeout=60) as r: return json.load(r)["result"]
def batch(calls):
    out=[]
    for i in range(0,len(calls),10):
        chunk=calls[i:i+10]
        body=[{"jsonrpc":"2.0","id":i+j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        req=urllib.request.Request(RPC,data=json.dumps(body).encode(),
            headers={"Content-Type":"application/json","User-Agent":"python-research"})
        with urllib.request.urlopen(req,timeout=120) as r: res=json.load(r)
        if isinstance(res,dict): res=[res]
        m={x["id"]:x.get("result") for x in res}
        out += [m.get(i+j) for j in range(len(chunk))]
    return out
def u(w): return int(w,16) if w and w!="0x" else 0
def ad(w): return "0x"+w[-40:] if w and len(w)>=40 else None
def pad(n): return format(n,"064x")
def pad_a(a): return a.lower().replace("0x","").rjust(64,"0")

blk=int(rpc("eth_blockNumber",[]),16)
out={"block":blk,"tower":TOWER}
res=rpc("eth_call",[{"to":TOWER,"data":"0x315c6359"+pad(0)+pad(1000)},"latest"])
raw=res[2:]; off=int(raw[0:64],16); n=int(raw[off*2:off*2+64],16)
elems=[]; base=off*2+64
for i in range(n):
    eoff=int(raw[base+i*64:base+i*64+64],16); p=base+eoff*2
    addr=ad(raw[p:p+64]); p+=64
    soff=int(raw[p:p+64],16); sp=base+eoff*2+soff*2
    slen=int(raw[sp:sp+64],16)
    name=bytes.fromhex(raw[sp+64:sp+64+slen*2]).decode("utf-8","replace")
    elems.append({"staking":addr,"name":name})
# stakingAsset + stakingCycle + cycleInfo + blackhole balance
calls=[]
for e in elems:
    calls.append(("eth_call",[{"to":e["staking"],"data":"0x7776768f"},"latest"]))
    calls.append(("eth_call",[{"to":e["staking"],"data":"0x9d143362"},"latest"]))
res=batch(calls)
for i,e in enumerate(elems):
    e["stakingAsset"]=ad(res[i*2]); e["stakingCycle"]=u(res[i*2+1])
calls=[]
for e in elems:
    calls.append(("eth_call",[{"to":e["staking"],"data":"0x44f79609"+pad(e["stakingCycle"])},"latest"]))
res=batch(calls)
for i,e in enumerate(elems):
    w=(res[i] or "0x")[2:]
    e["totalStaked"]=u(w[64:128]) if len(w)>=128 else None
calls=[]
for e in elems:
    calls.append(("eth_call",[{"to":e["stakingAsset"],"data":"0x70a08231"+pad_a(BLACKHOLE)},"latest"]))
res=batch(calls)
for i,e in enumerate(elems):
    e["blackholeBalance"]=u(res[i])
out["positions"]=elems
out["positionsCount"]=len(elems)
# other pools
extra={
 "manager_totalSupply":("0x18160ddd",MANAGER),
 "distributor_SDT":("0x70a08231"+pad_a(DIST),SDT),
 "blackhole_SDT":("0x70a08231"+pad_a(BLACKHOLE),SDT),
 "cvgSdtStaking_cvgSDT":("0x70a08231"+pad_a(CVGSDT_SVC),CVGSDT),
 "cvgSDT_totalSupply":("0x18160ddd",CVGSDT),
}
res=batch([("eth_call",[{"to":t,"data":d},"latest"]) for d,t in extra.values()])
out["extra"]={k:u(r) for (k,(d,t)),r in zip(extra.items(),res)}
json.dump(out,open("ci-out/live-state.json","w"),indent=1)
tot=sum(1 for e in elems if (e["totalStaked"] or 0)>0)
print(f"block={blk} positions={len(elems)} nonZero={tot} backed={sum(1 for e in elems if (e['blackholeBalance'] or 0)>=(e['totalStaked'] or 0))}")
print("extra:",json.dumps(out["extra"]))
