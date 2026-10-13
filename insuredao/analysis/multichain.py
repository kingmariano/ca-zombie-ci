#!/usr/bin/env python3
"""Multichain InsureDAO state: Arbitrum, Optimism, Astar (read-only)."""
import json, subprocess, urllib.request

CHAINS = {
    "arbitrum": {"rpc": "https://arb1.arbitrum.io/rpc",
                 "vault": "0x968C9718f420d5D4275C610C5c217598a6ade9f9"},
    "optimism": {"rpc": "https://mainnet.optimism.io",
                 "vault": "0x54F23d2fdC1E17D349B1Eb14d869fa4deD6A6D2b"},
    "astar": {"rpc": "https://evm.astar.network",
              "vault": "0x190dA1B9fA124BD872e9166bA3c7Dd656A11E8F8"},
}
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"

def sel(sig): return subprocess.check_output(["cast","sig",sig]).decode().strip()
def call(rpc, to, data, block="latest"):
    payload = {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},block]}
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":UA})
    r = json.load(urllib.request.urlopen(req, timeout=60))
    return r.get("result")

def bn(rpc):
    payload = {"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":UA})
    return int(json.load(urllib.request.urlopen(req, timeout=60))["result"],16)

def dec(x):
    if x in (None,"0x","0x0"): return None
    try: return int(x,16)
    except Exception: return x

S = {k:"0x"+sel(k)[2:] for k in ["valueAll()","token()","registry()","ownership()","balance()",
     "totalAttributions()","controller()","getAllMarkets()(address[])","decimals()","symbol()",
     "supply()","paused()","marketStatus()","attributions(address)","owner()","getOwner()"]}

out={}
for name,cfg in CHAINS.items():
    rpc=cfg["rpc"]; V=cfg["vault"]; d={}
    try:
        d["block"]=bn(rpc)
        d["code_len"]=len(call(rpc,V,"0x") or "0x")
        for f in ["token()","registry()","ownership()","balance()","totalAttributions()","valueAll()","controller()"]:
            d[f]=call(rpc,V,S[f])
        # decode addresses
        for f in ["token()","registry()","ownership()","controller()"]:
            v=d.get(f)
            d[f]=("0x"+v[-40:]) if isinstance(v,str) and len(v)>=42 else v
        ctrl=d.get("controller()")
        if ctrl and ctrl!="0x0000000000000000000000000000000000000000":
            d["controller.valueAll"]=dec(call(rpc,ctrl,S["valueAll()"]))
        d["balance"]=dec(d["balance()"]); d["totalAttributions"]=dec(d["totalAttributions()"]); d["valueAll"]=dec(d["valueAll()"])
        reg=d.get("registry()")
        if reg and reg!="0x0000000000000000000000000000000000000000":
            rv=call(rpc,reg,S["getAllMarkets()(address[])"])
            markets=[]
            try:
                raw=bytes.fromhex(rv[2:]); off=int.from_bytes(raw[0:32],"big"); ln=int.from_bytes(raw[off:off+32],"big")
                markets=["0x"+raw[off+32+j*32:off+64+j*32].hex() for j in range(ln)]
            except Exception as e:
                d["markets_err"]=str(e)
            d["markets"]=markets
            att={}
            for m in markets:
                a=call(rpc,V,S["attributions(address)"]+m[2:].rjust(64,"0"))
                if a and dec(a): att[m]=dec(a)
            d["market_attribs"]=att
    except Exception as e:
        d["error"]=repr(e)
    out[name]=d
print(json.dumps(out,indent=1))
