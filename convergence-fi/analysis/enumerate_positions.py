#!/usr/bin/env python3
"""Enumerate Convergence Fi tower stakings + cvgSdt state at latest block. Read-only.
RPC URL from env; output JSON contains chain data only (no secrets)."""
import json, os, sys, urllib.request

RPC = os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
TOWER = "0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7"
VIEWER = "0xA3A8cDA21f50b6737385E46FC9495a9998B05Ff0"
SEL = {
 "getSdtStakings": "0x315c6359",
 "getGlobalViewCvgSdtStaking": "0xc9df4f3d",
 "staking_token": "0x2dc7d74c",
 "token": "0xfc0c546a",
 "totalSupply": "0x18160ddd",
 "balanceOf": "0x70a08231",
 "owner": "0x8da5cb5b",
}

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"python-research"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["result"]

def batch(calls):
    out=[]
    for i in range(0,len(calls),10):
        chunk=calls[i:i+10]
        body=[{"jsonrpc":"2.0","id":i+j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        req=urllib.request.Request(RPC, data=json.dumps(body).encode(),
                                   headers={"Content-Type":"application/json","User-Agent":"python-research"})
        with urllib.request.urlopen(req, timeout=120) as r:
            res=json.load(r)
        if isinstance(res, dict): res=[res]
        m={x["id"]:x.get("result") for x in res}
        out += [m.get(i+j) for j in range(len(chunk))]
    return out

def pad_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def pad_u256(n): return format(n,"064x")

def dec_u256(w): return int(w,16) if w and w!="0x" else 0
def dec_addr(w): return "0x"+w[-40:] if w and w!="0x" else None

def eth_call(to, data, blk="latest"):
    return rpc("eth_call",[{"to":to,"data":data},blk])

def batch_calls(items, blk):
    # items: list of (to, data)
    return batch([("eth_call",[{"to":t,"data":d},blk]) for t,d in items])

blk = int(rpc("eth_blockNumber",[]),16)
out={"block":blk,"tower":TOWER,"viewer":VIEWER,"positions":[]}

# outer call: getSdtStakings(0,1000)
res = eth_call(TOWER, SEL["getSdtStakings"]+pad_u256(0)+pad_u256(1000), hex(blk))
# decode dynamic array of tuples (address, string)
raw = res[2:]
off = int(raw[0:64],16)
n = int(raw[off*2:off*2+64],16)
print("stakings:", n, file=sys.stderr)
elems=[]
base = off*2+64
for i in range(n):
    eoff = int(raw[base+i*64:base+i*64+64],16)
    p = base + eoff*2
    addr = dec_addr(raw[p:p+64]); p+=64
    # string: offset relative to tuple start
    soff = int(raw[p:p+64],16)
    sp = base + eoff*2 + soff*2
    slen = int(raw[sp:sp+64],16)
    name = bytes.fromhex(raw[sp+64:sp+64+slen*2]).decode("utf-8","replace")
    elems.append((addr,name))

# view each staking
views = batch_calls([(VIEWER, SEL["getGlobalViewCvgSdtStaking"]+pad_addr(a)) for a,_ in elems], hex(blk))
positions=[]
for (staking,name),v in zip(elems,views):
    w=v[2:]
    rec={"staking":staking,"name":name,
         "cvgSdt":dec_addr(w[0:64]),"stakingAddress":dec_addr(w[64:128]),
         "cvgCycle":dec_u256(w[128:192]),"previousTotal":dec_u256(w[192:256]),
         "actualTotal":dec_u256(w[256:320]),"nextTotal":dec_u256(w[320:384])}
    positions.append(rec)

# for each cvgSdt: staking_token, token, totalSupply, balanceOf(0) etc.
calls=[]
for p in positions:
    calls += [(p["cvgSdt"], SEL["staking_token"]), (p["cvgSdt"], SEL["token"]), (p["cvgSdt"], SEL["totalSupply"])]
res2 = batch_calls(calls, hex(blk))
for i,p in enumerate(positions):
    st, tk, ts = res2[i*3], res2[i*3+1], res2[i*3+2]
    p["staking_token"]=dec_addr(st) if st and st!="0x" else None
    p["token"]=dec_addr(tk) if tk and tk!="0x" else None
    p["cvgSdt_totalSupply"]=dec_u256(ts) if ts and ts!="0x" else None

out["positions"]=positions
json.dump(out, open(sys.argv[1] if len(sys.argv)>1 else "state_positions.json","w"), indent=1)
print("wrote", len(positions), "positions", file=sys.stderr)
