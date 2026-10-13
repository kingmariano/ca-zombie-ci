#!/usr/bin/env python3
"""Deep multichain check: Astar markets + Arbitrum/Optimism registries."""
import json, subprocess, urllib.request, hashlib

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
def sel(sig): return subprocess.check_output(["cast","sig",sig]).decode().strip()
def rpc(url, method, params):
    payload={"jsonrpc":"2.0","id":1,"method":method,"params":params}
    req=urllib.request.Request(url,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":UA})
    return json.load(urllib.request.urlopen(req,timeout=60)).get("result")
def call(url,to,data): return rpc(url,"eth_call",[{"to":to,"data":data},"latest"])
def code(url,to): return rpc(url,"eth_getCode",[to,"latest"])

def dec(x):
    if x in (None,"0x","0x0"): return None
    try: return int(x,16)
    except Exception: return x
def addr(x):
    return "0x"+x[-40:] if isinstance(x,str) and len(x)>=42 else x

S={k:"0x"+sel(k)[2:] for k in ["symbol()","decimals()","token()","valueAll()","balance()","totalAttributions()",
   "controller()","registry()","ownership()","getAllMarkets()(address[])","marketStatus()","paused()",
   "totalSupply()","name()","indexList(uint256)","indices(address)","targetLev()","locked()",
   "getOwner()(address)","attributions(address)","getVault(address)(address)","isListed(address)(bool)"]}

out={}

# ---------- ASTAR ----------
ast="https://evm.astar.network"
d={}
try:
    V="0x190dA1B9fA124BD872e9166bA3c7Dd656A11E8F8"
    d["token"]=addr(call(ast,V,S["token()"]))
    d["token.symbol"]=call(ast,d["token"],S["symbol()"])
    d["token.decimals"]=dec(call(ast,d["token"],S["decimals()"]))
    d["valueAll"]=dec(call(ast,V,S["valueAll()"]))
    d["balance"]=dec(call(ast,V,S["balance()"]))
    d["totalAttributions"]=dec(call(ast,V,S["totalAttributions()"]))
    d["controller"]=addr(call(ast,V,S["controller()"]))
    reg=addr(call(ast,V,S["registry()"]))
    d["registry"]=reg
    rv=call(ast,reg,S["getAllMarkets()(address[])"])
    markets=[]
    if rv:
        raw=bytes.fromhex(rv[2:]); off=int.from_bytes(raw[0:32],"big"); ln=int.from_bytes(raw[off:off+32],"big")
        markets=["0x"+raw[off+32+j*32:off+64+j*32].hex() for j in range(ln)]
    d["markets"]=[]
    for m in markets:
        mi={}
        mi["impl"]=None
        c=code(ast,m)
        if c and c.startswith("0x363d3d373d3d3d363d73"):
            mi["impl"]="0x"+c[2+20:2+20+40]
        mi["attrib"]=dec(call(ast,V,S["attributions(address)"]+m[2:].rjust(64,"0")))
        mi["status"]=dec(call(ast,m,S["marketStatus()"]))
        mi["paused"]=dec(call(ast,m,S["paused()"]))
        mi["symbol"]=call(ast,m,S["symbol()"])
        mi["supply"]=dec(call(ast,m,S["totalSupply()"]))
        d["markets"].append({"addr":m,**mi})
    d["impl_codes"]={}
    for m in d["markets"]:
        im=m["impl"]
        if im and im not in d["impl_codes"]:
            c=code(ast,im)
            d["impl_codes"][im]={"len":len(c)//2-1 if c else 0,
                                 "sha256":hashlib.sha256(bytes.fromhex(c[2:])).hexdigest()[:16] if c and c!="0x" else None}
except Exception as e:
    d["error"]=repr(e)
out["astar"]=d

# ---------- ARBITRUM ----------
arb="https://arb1.arbitrum.io/rpc"
d={}
try:
    V="0x968C9718f420d5D4275C610C5c217598a6ade9f9"
    reg=addr(call(arb,V,S["registry()"]))
    d["registry"]=reg
    d["registry.code_len"]=len(code(arb,reg) or "0x")//2-1
    rv=call(arb,reg,S["getAllMarkets()(address[])"])
    d["getAllMarkets.raw"]=rv
    d["valueAll"]=dec(call(arb,V,S["valueAll()"]))
    d["totalAttributions"]=dec(call(arb,V,S["totalAttributions()"]))
    ctrl=addr(call(arb,V,S["controller()"]))
    d["controller"]=ctrl
    d["controller.code_len"]=len(code(arb,ctrl) or "0x")//2-1
    # try registry functions
    d["isListed(0x0)"]=call(arb,reg,S["isListed(address)(bool)"]+"00"*32)
except Exception as e:
    d["error"]=repr(e)
out["arbitrum"]=d

# ---------- OPTIMISM ----------
op="https://mainnet.optimism.io"
d={}
try:
    V="0x54F23d2fdC1E17D349B1Eb14d869fa4deD6A6D2b"
    reg=addr(call(op,V,S["registry()"]))
    d["registry"]=reg
    d["registry.code_len"]=len(code(op,reg) or "0x")//2-1
    rv=call(op,reg,S["getAllMarkets()(address[])"])
    d["getAllMarkets.raw"]=rv
    d["valueAll"]=dec(call(op,V,S["valueAll()"]))
    d["totalAttributions"]=dec(call(op,V,S["totalAttributions()"]))
    ctrl=addr(call(op,V,S["controller()"]))
    d["controller"]=ctrl
    d["controller.code_len"]=len(code(op,ctrl) or "0x")//2-1
except Exception as e:
    d["error"]=repr(e)
out["optimism"]=d

print(json.dumps(out,indent=1))
