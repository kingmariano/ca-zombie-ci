import json, os, urllib.request, time
FRESH="0x2222222222222222222222222222222222222222"
eps=None
def _eps():
    global eps
    if eps is None:
        import os
        eps=[("https://base.drpc.org",{"X-API-Key":os.environ.get("DRPC_API_KEY","")}),("https://base-rpc.publicnode.com",{}),("https://mainnet.base.org",{})]
    return eps
def rpc(method,params,tries=3):
    last=None
    for a in range(tries):
        for url,h in _eps():
            try:
                req=urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                    headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0",**h})
                r=json.load(urllib.request.urlopen(req,timeout=20))
                if "result" in r or "error" in r: return r
            except Exception as e: last=e; time.sleep(0.3)
    return {"error":{"message":str(last)}}
def enc_args(types):
    n=len(types); head=[]; tail=""; head_sz=32*n
    parts=[]
    for t in types:
        if t=="address": parts.append("0"*24+FRESH[2:])
        elif t.startswith("uint"): parts.append(format(10**18,"064x"))
        elif t=="bool": parts.append(format(0,"064x"))
        elif t=="bytes32": parts.append("11"*32)
        else: parts.append(None)
    for i,t in enumerate(types):
        if parts[i] is not None:
            head.append(parts[i])
        else:
            off=head_sz+len(tail)//2; head.append(format(off,"064x"))
            if t=="bytes": tail+="0"*64
            else: tail+="0"*64
    return "".join(head)+tail
def call(to,data,frm=FRESH,gas="0x1c9c380"):
    r=rpc("eth_call",[{"from":frm,"to":to,"data":data,"gas":gas},"latest"])
    if "result" in r: return ("OK", r["result"])
    d=r.get("error",{}).get("data"); m=r.get("error",{}).get("message","")
    v=str(d) if d else str(m)
    if v.startswith("0x08c379a0") and len(v)>=138:
        try:
            raw=bytes.fromhex(v[2:]); ln=int.from_bytes(raw[36:68],"big")
            return ("REV","Error(\""+raw[68:68+ln].decode(errors="replace")+"\")")
        except Exception: pass
    if v.startswith("0x4e487b71"): return ("REV","Panic")
    return ("REV",v[:80])
