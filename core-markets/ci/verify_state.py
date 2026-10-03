#!/usr/bin/env python3
"""Read-only live-state verification for Core Markets (Blast).
Uses public RPCs only. Writes ci-out/live_state.json.
"""
import json, os, subprocess, sys, urllib.request

RPCS = [
    os.environ.get("BLAST_RPC_URL", ""),
    "https://rpc.blast.io",
    "https://blast-rpc.publicnode.com",
    "https://blast.drpc.org",
]

def pick_rpc():
    for u in RPCS:
        if not u:
            continue
        try:
            req = urllib.request.Request(u, data=json.dumps(
                {"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),
                headers={"Content-Type":"application/json","User-Agent":"research"})
            r = json.load(urllib.request.urlopen(req, timeout=15))
            if "result" in r:
                return u
        except Exception:
            continue
    return None

RPC = pick_rpc()
if not RPC:
    print("FATAL: no working Blast RPC")
    sys.exit(1)
print("using RPC:", RPC)

def sel(sig):
    return subprocess.run(["cast","keccak",sig],capture_output=True,text=True).stdout.strip()[:10]

def pad(a): return a.lower().replace("0x","").rjust(64,"0")

def batch(calls):
    payload=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"research"})
    out=json.load(urllib.request.urlopen(req,timeout=120))
    return {r["id"]:r.get("result",r.get("error")) for r in out}

USDB="0x4300000000000000000000000000000000000003"
CORE="0x233b23de890a8c21f6198d03425a2b986ae05536"
A={
 "farm":"0xf1337755abe2f7bcac0b10736dc2b646c754a886",
 "symmio_diamond":"0x3d17f073ccb9c3764f105550b0bcf9550477d266",
 "treasury_safe":"0xC793Bec2483465F9220852eeb614242e9a62C1d2",
 "xcore_vault":"0xE659f8e705f86845e9de5c4d1e6f785697ac85e5",
 "xcore_rewarder":"0x5cba6447894BC1D765A35300f1FBa3ab3a932b21",
 "team_vesting":"0x9cD047D06A2daCf09cAC42324aD2b6cBa1CA8b44",
 "emissions":"0xd8c1e4eac58ee0d9dd2763480adaeca43b06fe67",
 "lbp":"0x9fb9af399c7E9bda57b89905c7D96091B895bfAe",
 "multi_account":"0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e",
}
calls=[("eth_blockNumber",[])]; labels=["block"]
for name,a in A.items():
    calls.append(("eth_call",[{"to":USDB,"data":sel("balanceOf(address)")+pad(a)},"latest"])); labels.append(name+".USDB")
    calls.append(("eth_call",[{"to":CORE,"data":sel("balanceOf(address)")+pad(a)},"latest"])); labels.append(name+".CORE")
# states
calls.append(("eth_call",[{"to":CORE,"data":sel("paused()")},"latest"])); labels.append("core.paused")
calls.append(("eth_call",[{"to":A["xcore_vault"],"data":sel("totalAssets()")},"latest"])); labels.append("xcore.totalAssets")
calls.append(("eth_call",[{"to":A["xcore_vault"],"data":sel("totalSupply()")},"latest"])); labels.append("xcore.totalSupply")
calls.append(("eth_call",[{"to":A["lbp"],"data":sel("closed()")},"latest"])); labels.append("lbp.closed")
calls.append(("eth_call",[{"to":A["symmio_diamond"],"data":sel("getCollateral()")},"latest"])); labels.append("symmio.collateral")

r=batch(calls)
block=int(r[0],16)
vals={}
for i,l in enumerate(labels):
    v=r.get(i)
    if l=="block": vals[l]=block; continue
    if l.endswith(".USDB") or l.endswith(".CORE") or l in ("xcore.totalAssets","xcore.totalSupply"):
        vals[l]=int(v,16)/1e18 if isinstance(v,str) else v
    elif l in ("core.paused","lbp.closed"):
        vals[l]=bool(int(v,16)) if isinstance(v,str) else v
    else:
        vals[l]=v

# spot prices
def http(url):
    try:
        return json.load(urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":"research"}),timeout=30))
    except Exception:
        return None
usdb_price=0.99; core_price=None
p=http("https://coins.llama.fi/prices/current/blast:"+USDB)
if p and p.get("coins"):
    usdb_price=list(p["coins"].values())[0]["price"]
g=http("https://api.geckoterminal.com/api/v2/networks/blast/tokens/"+CORE)
if g and g.get("data"):
    core_price=g["data"]["attributes"].get("price_usd")
    reserve=g["data"]["attributes"].get("total_reserve_in_usd")

out={
 "chain":"blast","chain_id":81457,"block":block,"rpc":RPC,
 "prices":{"usdb_usd":usdb_price,"core_usd":core_price,"core_total_dex_reserve_usd":reserve},
 "balances":vals,
 "usd":{
   "farm_usdb_usd": round(vals["farm.USDB"]*usdb_price,2),
   "symmio_usdb_usd": round(vals["symmio_diamond.USDB"]*usdb_price,2),
   "treasury_usdb_usd": round(vals["treasury_safe.USDB"]*usdb_price,2),
   "core_nominal_usd": 0,
 },
 "note":"Read-only verification; no transactions sent. E-U expected $0 per audit.",
}
if core_price:
    out["usd"]["core_nominal_usd"]=round(99889460.92*core_price,2)

os.makedirs("ci-out",exist_ok=True)
json.dump(out,open("ci-out/live_state.json","w"),indent=1)
print(json.dumps(out,indent=1))
print("wrote ci-out/live_state.json")
