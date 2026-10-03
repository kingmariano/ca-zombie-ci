#!/usr/bin/env python3
"""Read user positions (config bitmap + per-reserve balances) for a list of users."""
import json, sys, time
import requests
from eth_utils import keccak

RPC_URL="https://blast-rpc.publicnode.com"
D="0x742316f430002D067dC273469236D0F3670bE446"
POOL="0xd2499b3c8611E36ca89A70Fda2A72C49eE19eAa8"
SEL={k:"0x"+keccak(text=v).hex()[:8] for k,v in {
 "getUserConfiguration":"getUserConfiguration(address)",
 "getUserReserveData":"getUserReserveData(address,address)",
 "getUserEMode":"getUserEMode(address)",
 "getUserAccountData":"getUserAccountData(address)",
 "scaledBalanceOf":"scaledBalanceOf(address)",
 "balanceOf":"balanceOf(address)",
}.items()}
def addr_pad(a): return a.lower().replace("0x","").rjust(64,"0")
class RPC:
    def __init__(s,url): s.url=url; s.id=0; s.s=requests.Session(); s.s.headers.update({"Content-Type":"application/json","User-Agent":"zombie-hunt/1.0"})
    def batch(s,calls):
        payload=[]
        for to,data in calls:
            s.id+=1; payload.append({"jsonrpc":"2.0","id":s.id,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
        for att in range(4):
            try:
                js=s.s.post(s.url,json=payload,timeout=90).json()
                out={i["id"]:(i.get("result"),i.get("error")) for i in js}
                return [out[p["id"]] for p in payload]
            except Exception as e:
                if att==3: raise
                time.sleep(1.5*(att+1))
rpc=RPC(RPC_URL)

reserves=json.load(open("/home/heisenberg/CA/pac-finance/analysis/reserves_raw.json"))
order=list(reserves["reserves"].keys())
symbols={a:reserves["reserves"][a]["symbol"] for a in order}
users=[l.strip() for l in open(sys.argv[1]) if l.strip()]
out={}
for u in users:
    rec={}
    s,e=rpc.batch([(POOL,SEL["getUserConfiguration"]+addr_pad(u))])[0]
    if e or not s: rec["config_error"]=e; out[u]=rec; print("cfg fail",u,e,file=sys.stderr); continue
    raw=s[2:]
    # UserConfigurationMap is a single uint256: word0
    bitmap=int(raw[:64],16)
    rec["bitmap"]=str(bitmap)
    rec["emode"]=None
    s2,e2=rpc.batch([(POOL,SEL["getUserEMode"]+addr_pad(u))])[0]
    if s2 and not e2: rec["emode"]=int(s2[2:],16)
    positions={}
    for i,a in enumerate(order):
        borrow = (bitmap>>(2*i))&1
        coll = (bitmap>>(2*i+1))&1
        if borrow or coll:
            s3,e3=rpc.batch([(D,SEL["getUserReserveData"]+addr_pad(a)+addr_pad(u))])[0]
            if s3 and not e3:
                vals=s3[2:]
                # (uint256 currentATokenBalance, uint256 currentStableDebt, uint256 currentVariableDebt, uint256 principalStableDebt, uint256 scaledVariableDebt, uint256 stableBorrowRate, uint256 liquidityRate)
                at=int(vals[0:64],16); sd=int(vals[64:128],16); vd=int(vals[128:192],16)
                svd=int(vals[256:320],16); lr=int(vals[384:448],16)
                positions[symbols[a]]={"asset":a,"collateral":bool(coll),"borrow":bool(borrow),
                    "aBalance":str(at),"variableDebt":str(vd),"scaledVariableDebt":str(svd),"liquidityRate":str(lr)}
            else:
                positions[symbols[a]]={"asset":a,"collateral":bool(coll),"borrow":bool(borrow),"error":e3}
    rec["positions"]=positions
    out[u]=rec
    print("done",u,file=sys.stderr)
json.dump(out,open(sys.argv[2],"w"),indent=1)
print(json.dumps(out,indent=1)[:200])
