#!/usr/bin/env python3
"""Query wrapped vaults, V1 vault queues, and frontier oracles (public drpc RPC)."""
import json, time, urllib.request

RPCS = ["https://base.drpc.org", "https://mainnet.base.org"]
def rpc_batch(calls, chunk=8):
    res=[]
    for i in range(0,len(calls),chunk):
        sub=calls[i:i+chunk]
        got=None
        for a in range(3):
            rpc=RPCS[a%len(RPCS)]
            payload=[{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[{"to":t,"data":d},"latest"]} for j,(t,d) in enumerate(sub)]
            req=urllib.request.Request(rpc,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            try:
                out=json.load(urllib.request.urlopen(req,timeout=40))
                m={it["id"]:it.get("result") for it in out}
                got=[m.get(j) for j in range(len(sub))]
                if all(x is not None for x in got): break
            except Exception as e: pass
            time.sleep(1)
        res.extend(got if got else [None]*len(sub))
    return res

def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def u(h): return int(h,16) if h else None
def s(h):
    if not h or h=="0x": return None
    b=bytes.fromhex(h[2:]); off=int.from_bytes(b[:32],"big"); ln=int.from_bytes(b[off:off+32],"big")
    return b[off+32:off+32+ln].decode(errors="replace")
S={"asset":"0x38d52e0f","totalAssets":"0x01e1d114","totalSupply":"0x18160ddd","owner":"0x8da5cb5b","curator":"0xe66f53b7","adaptersLength":"0x5aa22bc8","liquidityAdapter":"0xad468d11","name":"0x06fdde03","withdrawQueueLength":"0x33f91ebb","withdrawQueue":"0x62518ddf","supplyQueueLength":"0xa17b3130","config":"0xcc718f76","skimRecipient":"0x388af5b5","fee":"0xddca3f43","isAllocator":"0x4dedf20e","MORPHO":"0x2c3c9157"}

out={}
# 1) wrapped vaults
wrapped={
 "wmpUSDC":"0x036A01eFdDC87F6634FFDE0533EE528b90fc7A45",
 "wmpWETH":"0x548653b09b03A69f93B3890c382fE9DcD245cbc4",
 "wmpcbBTC":"0x0e0a857d2AF1A2d43c82d1FA54766239CAb70147",
 "wmfUSDC":"0x54D8417bD21C86A7806b58f5aa2e2E0bB88B856A",
}
print("=== wrapped vaults ===")
for n,a in wrapped.items():
    calls=[(a,S[k]) for k in ["name","asset","totalAssets","totalSupply","owner","curator","adaptersLength","liquidityAdapter"]]
    r=rpc_batch(calls)
    d={"address":a,"name":s(r[0]),"asset":"0x"+r[1][-40:] if r[1] else None,"totalAssets":u(r[2]),"totalSupply":u(r[3]),
       "owner":"0x"+r[4][-40:] if r[4] else None,"curator":"0x"+r[5][-40:] if r[5] else None,"adaptersLength":u(r[6]),
       "liquidityAdapter":"0x"+r[7][-40:] if r[7] else None}
    out[n]=d; print(n, json.dumps(d))
    # adapter shares held in the corresponding direct vault
# 2) V1 vaults queues
print("=== V1 vault queues ===")
v1={"usdc_v1":"0xf7e26Fa48A568b8b0038e104DfD8ABdf0f99074F","cbbtc_v1":"0xAeCc8113a7bD0CFAF7000EA7A31afFD4691ff3E9","weth_v1":"0x21e0d366272798da3A977FEBA699FCB91959d120"}
for n,a in v1.items():
    r=rpc_batch([(a,S["withdrawQueueLength"]),(a,S["skimRecipient"]),(a,S["totalAssets"]),(a,S["totalSupply"])])
    qlen=u(r[0]) or 0
    q=rpc_batch([(a,S["withdrawQueue"]+hex(i)[2:].rjust(64,"0")) for i in range(qlen)])
    ids=["0x"+x[-64:] for x in q if x]
    d={"address":a,"withdrawQueueLength":qlen,"skimRecipient":"0x"+r[1][-40:] if r[1] else None,"totalAssets":u(r[2]),"totalSupply":u(r[3]),"withdrawQueue":ids}
    out[n]=d; print(n, json.dumps(d)[:400])
# 3) frontier oracles
print("=== frontier oracles ===")
oracles={
 "cbXRP_mkt":"0x031b2efc8d70042ac8d9f5c793c4149ec4b60fde",
 "cbHYPE_mkt":"0x7fad8b8de2ddb7b4b415e1aa3613e45eef9e4bff",
 "SOL_mkt":"0xe9725430f3a72611ac72eddc650625bce4f45dc7",
 "cbADA_mkt":"0x35d87a743d1f2f7cafb42d855dc1c5df857ce45f",
 "m1":"0xa3cb2d7204f47a468b82c6fab1ca9675e9f7a272","m2":"0x47f961e6653423a77b1ef8fb680ee53bf7d8a00d",
 "m3":"0xa9d36600fb9eba7548857e61f836ec951e3091b2","m4":"0x9079857a2b5fffc3d87052b11b866a185b4a6483","m5":"0x78f772f5fcc03256260cc1165e34da9bb3f9be1c"}
def sel(sig): 
    import subprocess
    return subprocess.run(["cast","sig",sig],capture_output=True,text=True).stdout.strip()
for n,o in oracles.items():
    r=rpc_batch([(o,sel("price()")),(o,sel("BASE_FEED_1()")),(o,sel("QUOTE_FEED_1()"))])
    d={"oracle":o,"price":u(r[0]),"base_feed":"0x"+r[1][-40:] if r[1] else None,"quote_feed":"0x"+r[2][-40:] if r[2] else None}
    out["oracle_"+n]=d; print(n, json.dumps(d))
json.dump(out,open("wrapped-v1-oracles.json","w"),indent=1)
print("saved")
