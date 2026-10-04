#!/usr/bin/env python3
"""Multichain read-only state probe for pNetwork contracts (JSON-RPC batch)."""
import json, sys, urllib.request, subprocess

def load_env():
    env = {}
    for line in open('/home/heisenberg/CA/.env'):
        if '=' in line and not line.strip().startswith('#'):
            k, v = line.strip().split('=', 1)
            env[k] = v.strip().strip('"').strip("'")
    return env
ENV = load_env()
BSC_RPC = "https://bsc-mainnet.nodereal.io/v1/" + ENV['NODEREAL_API_KEY']
ETH_RPC = "https://ethereum-rpc.publicnode.com"

def sel(sig):
    return subprocess.check_output(["cast","sig",sig]).decode().strip()

FUNCS = {f: sel(sig) for f, sig in {
    "name":"name()", "symbol":"symbol()", "decimals":"decimals()",
    "totalSupply":"totalSupply()", "owner":"owner()",
    "gsnTrustedSigner":"gsnTrustedSigner()", "PNETWORK":"PNETWORK()",
    "MINTER_ROLE":"MINTER_ROLE()", "paused":"paused()", "admin":"admin()",
    "hub":"hub()", "factory":"factory()", "epochsManager":"epochsManager()",
    "isLockedDown":"isLockedDown()", "currentEpoch":"currentEpoch()",
    "numberOfOperationsInQueue":"numberOfOperationsInQueue()",
    "teeAddress":"teeAddress()", "interimChainNetworkId":"interimChainNetworkId()",
    "getCurrentNetworkId":"getCurrentNetworkId()",
    "isInitialized":"isInitialized()", "implementation":"implementation()",
}.items()}

def rpc_batch(url, calls, block="latest"):
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":addr,"data":data}, block]} for i,(addr,data) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    out = json.load(urllib.request.urlopen(req, timeout=60))
    res = {}
    for item in out:
        res[item["id"]] = item.get("result", item.get("error"))
    return [res.get(i) for i in range(len(calls))]

def probe(url, addresses, funcs):
    calls=[]; meta=[]
    for a in addresses:
        for f in funcs:
            calls.append((a, FUNCS[f])); meta.append((a,f))
    results = rpc_batch(url, calls)
    out={}
    for (a,f),r in zip(meta,results):
        out.setdefault(a,{})[f]=r
    return out

def dec_hex_str(h):
    if not isinstance(h,str) or not h.startswith("0x"): return h
    if len(h)<3: return h
    try:
        b=bytes.fromhex(h[2:])
        if len(b)>=64:
            off=int.from_bytes(b[:32],'big')
            if off+32<=len(b):
                ln=int.from_bytes(b[off:off+32],'big')
                if off+32+ln<=len(b):
                    return b[off+32:off+32+ln].decode('utf-8',errors='replace')
        return h
    except Exception:
        return h

if __name__ == "__main__":
    chain, addrfile, funcsjson = sys.argv[1], sys.argv[2], sys.argv[3]
    outfile = sys.argv[4] if len(sys.argv)>4 else "analysis/state_out.json"
    addrs = json.load(open(addrfile))
    funcs = json.loads(funcsjson)
    url = ETH_RPC if chain=="eth" else BSC_RPC
    res = probe(url, addrs, funcs)
    out={}
    for a,v in res.items():
        row={}
        for f,val in v.items():
            if isinstance(val,dict): row[f]=val
            elif f in ("name","symbol"): row[f]=dec_hex_str(val)
            else: row[f]=val
        out[a]=row
        print(a, json.dumps(row)[:500])
    json.dump(out, open(outfile,"w"), indent=1)
