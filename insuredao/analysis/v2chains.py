#!/usr/bin/env python3
"""v2 chains: enumerate pools/markets, implementations, statuses (read-only)."""
import json, subprocess, urllib.request, hashlib

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
def sel(s): return subprocess.check_output(["cast","sig",s]).decode().strip()
def rpc(u,m,p):
    req=urllib.request.Request(u,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),
        headers={"Content-Type":"application/json","User-Agent":UA})
    return json.load(urllib.request.urlopen(req,timeout=60)).get("result")
def call(u,to,d): return rpc(u,"eth_call",[{"to":to,"data":d},"latest"])
def code(u,to): return rpc(u,"eth_getCode",[to,"latest"])
def dec(x):
    if x in (None,"0x","0x0"): return None
    try: return int(x,16)
    except Exception: return x
def a20(x): return "0x"+x[-40:] if isinstance(x,str) and len(x)>=42 else x
def arr(x):
    if not x: return None
    try:
        raw=bytes.fromhex(x[2:]); off=int.from_bytes(raw[0:32],"big"); ln=int.from_bytes(raw[off:off+32],"big")
        return ["0x"+raw[off+32+j*32+12:off+64+j*32].hex() for j in range(ln)]
    except Exception: return None

S={k:"0x"+sel(k)[2:] for k in ["getAllPools()(address[])","getAllMarkets()(address[])","isListed(address)(bool)",
  "marketStatus()","paused()","locked()","symbol()","totalSupply()","token()","valueAll()","attributions(address)",
  "registry()","vault()","getReserve(address)(address)","indexList(uint256)","poolList(uint256)","allInsuranceCount()"]}

out={}
for chain,url,V,reg in [
    ("arbitrum","https://arb1.arbitrum.io/rpc","0x968C9718f420d5D4275C610C5c217598a6ade9f9","0x0fa85c39c96a9172ccca7f84ce68e08a2bb971c1"),
    ("optimism","https://mainnet.optimism.io","0x54F23d2fdC1E17D349B1Eb14d869fa4deD6A6D2b","0x636938b5ff717f525c696f8961b9a1aec38749a1"),
    ("astar","https://evm.astar.network","0x190dA1B9fA124BD872e9166bA3c7Dd656A11E8F8","0xd0df5a352d74a746754c592a6277c9060a7c9c87"),
]:
    d={}
    pools=arr(call(url,reg,S["getAllPools()(address[])"]))
    if pools is None:
        pools=arr(call(url,reg,S["getAllMarkets()(address[])"]))
    d["pools"]=[]
    for p in pools or []:
        e={"addr":p}
        c=code(url,p)
        e["code_len"]=len(c)//2-1 if c and c!="0x" else 0
        e["impl"]="0x"+c[2+20:2+20+40] if c and c.startswith("0x363d3d373d3d3d363d73") else None
        e["sha"]=hashlib.sha256(bytes.fromhex(c[2:])).hexdigest()[:12] if c and c!="0x" else None
        e["attrib"]=dec(call(url,V,S["attributions(address)"]+p[2:].rjust(64,"0")))
        for f,key in [("marketStatus()","status"),("paused()","paused"),("locked()","locked"),
                      ("symbol()","symbol"),("totalSupply()","supply"),("allInsuranceCount()","insCount")]:
            e[key]=dec(call(url,p,S[f]))
        d["pools"].append(e)
    d["impl_codes"]={}
    for e in d["pools"]:
        if e["impl"] and e["impl"] not in d["impl_codes"]:
            c=code(url,e["impl"])
            d["impl_codes"][e["impl"]]={"len":len(c)//2-1 if c and c!="0x" else 0,
                                        "sha":hashlib.sha256(bytes.fromhex(c[2:])).hexdigest()[:16] if c and c!="0x" else None}
    out[chain]=d

# compare vault code hashes across chains
out["vault_hashes"]={}
for chain,url,V in [("ethereum","https://ethereum-rpc.publicnode.com","0x131fb74c6fede6d6710ff224e07ce0ed8123f144"),
                    ("arbitrum","https://arb1.arbitrum.io/rpc","0x968C9718f420d5D4275C610C5c217598a6ade9f9"),
                    ("optimism","https://mainnet.optimism.io","0x54F23d2fdC1E17D349B1Eb14d869fa4deD6A6D2b"),
                    ("astar","https://evm.astar.network","0x190dA1B9fA124BD872e9166bA3c7Dd656A11E8F8")]:
    c=code(url,V)
    out["vault_hashes"][chain]={"len":len(c)//2-1 if c and c!="0x" else 0,
                                "sha":hashlib.sha256(bytes.fromhex(c[2:])).hexdigest()[:16] if c and c!="0x" else None}
print(json.dumps(out,indent=1))
