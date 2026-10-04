#!/usr/bin/env python3
"""Enumerate pNetwork vault collateral on Ethereum: supported tokens + balances."""
import json, sys, urllib.request, subprocess, time

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    if '=' in line and not line.strip().startswith('#'):
        k,v = line.strip().split('=',1); ENV[k]=v.strip().strip('"').strip("'")
RPC = "https://ethereum-rpc.publicnode.com"

def sel(sig): return subprocess.check_output(["cast","sig",sig]).decode().strip()
S = {f: sel(sig) for f,sig in {
  "getSupportedTokens":"getSupportedTokens()","PNETWORK":"PNETWORK()","weth":"weth()",
  "balanceOf":"balanceOf(address)","symbol":"symbol()","decimals":"decimals()",
  "name":"name()","ORIGIN_CHAIN_ID":"ORIGIN_CHAIN_ID()","adminWithdrawAllowed":"adminWithdrawAllowed(address)",
}.items()}

def rpc(method, params):
    payload={"jsonrpc":"2.0","id":1,"method":method,"params":params}
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req,timeout=60))

def batch(calls):
    payload=[{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":a,"data":d},"latest"]} for i,(a,d) in enumerate(calls)]
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    out=json.load(urllib.request.urlopen(req,timeout=90))
    res={}
    for it in out: res[it["id"]]=it.get("result",it.get("error"))
    return [res.get(i) for i in range(len(calls))]

def dec_arr_addresses(h):
    if not isinstance(h,str) or not h.startswith("0x") or len(h)<130: return None
    b=bytes.fromhex(h[2:])
    off=int.from_bytes(b[:32],'big'); ln=int.from_bytes(b[off:off+32],'big')
    out=[]
    for i in range(ln):
        out.append("0x"+b[off+32+32*i:off+64+32*i][12:].hex())
    return out

def dec_str(h):
    if not isinstance(h,str) or not h.startswith("0x") or len(h)<130: return h
    try:
        b=bytes.fromhex(h[2:]); off=int.from_bytes(b[:32],'big'); ln=int.from_bytes(b[off:off+32],'big')
        return b[off+32:off+32+ln].decode('utf-8','replace')
    except Exception: return h

def main():
    vaults=json.load(open(sys.argv[1]))
    # 1) getSupportedTokens + PNETWORK
    res=batch([(v,S["getSupportedTokens"]) for v in vaults]+[(v,S["PNETWORK"]) for v in vaults])
    toks=res[:len(vaults)]; pnet=res[len(vaults):]
    out={}
    token_calls=[]; token_meta=[]
    for v,t,p in zip(vaults,toks,pnet):
        supported=dec_arr_addresses(t) if isinstance(t,str) else None
        out[v]={"PNETWORK": (p if isinstance(p,str) else None), "supported": supported or [], "balances":{}}
        for tk in (supported or []):
            token_calls.append((tk,S["balanceOf"]+v[2:].lower().rjust(64,'0')))
            token_meta.append((v,tk))
    if token_calls:
        bals=batch(token_calls)
        for (v,tk),b in zip(token_meta,bals):
            out[v]["balances"][tk]=b if isinstance(b,str) else None
    json.dump(out,open(sys.argv[2],"w"),indent=1)
    for v,info in out.items():
        if not info["supported"]: continue
        def _int(b):
            try: return int(b,16) if isinstance(b,str) and b.startswith("0x") and len(b)>2 else 0
            except Exception: return 0
        nz=[(tk,_int(b)) for tk,b in info["balances"].items()]
        nz=[x for x in nz if x[1]>0]
        print(v,"PNETWORK=",info["PNETWORK"],"supported=",len(info["supported"]),"nonzero=",nz)

if __name__=="__main__": main()
