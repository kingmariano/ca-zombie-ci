#!/usr/bin/env python3
"""Enumerate InsureDAO pool<->index graph + per-index state (read-only)."""
import json, os, subprocess, urllib.request

RPCS = [u for u in [os.environ.get("RPC_URL"), "https://ethereum-rpc.publicnode.com",
                    "https://eth.drpc.org"] if u]
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
POOLS = [  # 26 PoolTemplate markets
    "0x1CF1195aFB01DD115647E4989e63AfE6DdD65030","0xDFdFcFEdb96e0979825C6B463cb8a971fE367d5D",
    "0xC03Ab4bB777Edf97e8692bd125968358aD3b7F08","0xbDB009e6C9dd3F77d6A7f507A4F817133677257c",
    "0x22453153978D0C25f86010c0fd405527feD9764b","0x8dfFb0c2b2d0A126f13667C0825ba7c026ECb24a",
    "0x8c4943100bEc96e3381a544Da82B91713a4BC062","0x961DfEcFf7C530505BC31FF7fa92dAa0eEED18c7",
    "0x641BE011738C65AAc8FF3f5d4e6dedbBD7411f47","0x0a3f739246846fC024F7f8dd5CBe7E0adf77760F",
    "0xB0AC0465320E9289BE7a9dF0d86B136d56C83722","0xbb236F4D55EAc44713e6A3E623f7775550266887",
    "0x58803187E676b180eD12b4F7d79b94cA011f4b8e","0xB127A53646EEfF7a0a787b754258B101D782Db0C",
    "0x7a1815401D91307c883eb987C1Ec16D9812aC8dc","0x3bfE4119De068710485704f974B16C563aEC715f",
    "0xdF7A7BC927a148B78850A789628627681977bb18","0x947031FDDE0156acAd1Ef17C89889FA0c82A8597",
    "0xe0BEF490D49F3dBcbaedAC6F79713F02C73f87Ce","0x772F71eF550a49f3fCd96d5cBdF5dEA2e9233A6a",
    "0x5E9aC74012B9924aC1bB0320d531aa7440c09Cb6","0xB6e3816D4F3C263CAEDB15A6BA65ACA1FCa16318",
    "0x3005f4fA9B678F80216bc3cD8d8a5F7894fC70f2","0x71571F8895803Ee067E4595f5dA3E2C4EF513A69",
    "0x197c8827621aa1A7276D7D7a83eed0D0b7B8B3F2","0x86c82E8cD8A865f01A8CeBed870Af5d58e69a439",
]
INDEXES = ["0xDAea5b1B6b12Ac4c4f51aB12649e96ab3aB98C3A","0xd5f1Ab3c61eF3a6a6f1AA6141256Aa008D2fb5A1","0x7E08daB409Ad1bCeBc5bE5674CB2C0f3540A4d3d"]
VAULT="0x131fb74c6fede6d6710ff224e07ce0ed8123f144"

def sel(sig): return subprocess.check_output(["cast","sig",sig]).decode().strip()
def rpc_batch(calls):
    payload=[{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[c,"latest"]} for i,c in enumerate(calls)]
    for url in RPCS:
        try:
            req=urllib.request.Request(url,data=json.dumps(payload).encode(),
                headers={"Content-Type":"application/json","User-Agent":UA})
            r=json.load(urllib.request.urlopen(req,timeout=90))
            if isinstance(r,list): return {x["id"]:x.get("result") for x in r}, url
        except Exception: continue
    raise RuntimeError("rpcs failed")
def addr_arg(a): return a[2:].lower().rjust(64,"0")
def dec(x):
    if x in (None,"0x","0x0"): return None
    try: return int(x,16)
    except Exception: return x

S={k:"0x"+sel(k)[2:] for k in ["indexList(uint256)","poolList(uint256)","indices(address)",
   "allocPoints(address)","totalAllocPoint()","pendingPremium(address)","getAllPools()(address[])",
   "paused()","locked()","marketStatus()","totalCredit()","attributionDebt()","totalLiquidity()"]}

calls=[];meta=[]
for p in POOLS:
    for i in range(10):
        calls.append({"to":p,"data":S["indexList(uint256)"]+hex(i)[2:].rjust(64,"0")});meta.append((p,f"indexList[{i}]"))
    calls.append({"to":p,"data":S["totalCredit()"]});meta.append((p,"totalCredit"))
    calls.append({"to":p,"data":S["attributionDebt()"]});meta.append((p,"attributionDebt"))
    calls.append({"to":p,"data":S["totalLiquidity()"]});meta.append((p,"totalLiquidity"))
    calls.append({"to":p,"data":S["locked()"] if False else S["marketStatus()"]});meta.append((p,"marketStatus"))
    calls.append({"to":p,"data":S["paused()"]});meta.append((p,"paused"))
for x in INDEXES:
    calls.append({"to":x,"data":S["getAllPools()(address[])"]});meta.append((x,"getAllPools"))
    calls.append({"to":x,"data":S["totalAllocPoint()"]});meta.append((x,"totalAllocPoint"))
    calls.append({"to":x,"data":S["locked()"]});meta.append((x,"locked"))
    calls.append({"to":x,"data":S["paused()"]});meta.append((x,"paused"))
res,used=rpc_batch(calls)
out={}
ADDR={"indexList","getAllPools"}
for i,(a,f) in enumerate(meta):
    v=res.get(i)
    if f.startswith("indexList") or f=="getAllPools":
        val=v
        if v and len(v)>=130:
            # could be array (for getAllPools) or address
            if f=="getAllPools":
                try:
                    raw=bytes.fromhex(v[2:]); off=int.from_bytes(raw[0:32],"big"); ln=int.from_bytes(raw[off:off+32],"big")
                    val=["0x"+raw[off+32+j*32:off+64+j*32].hex() for j in range(ln)]
                except Exception: val=v
            else:
                val="0x"+v[-40:]
        out.setdefault(a,{})[f]=val
    else:
        out.setdefault(a,{})[f]=dec(v)
print(json.dumps({"rpc":used,"graph":out},indent=1))
