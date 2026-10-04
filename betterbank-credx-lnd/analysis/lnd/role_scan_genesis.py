#!/usr/bin/env python3
"""Fill genesis windows for role events + HL retry."""
import json, sys, time
sys.path.insert(0,'.')
from lib import rpc, SONIC, HL

T_GRANT = "0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d"
T_REVOKE= "0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b"

def one(url, addr, b, to, topic, tag, retries=6):
    for i in range(retries):
        try:
            logs=rpc(url,"eth_getLogs",[{"address":addr,"topics":[topic],"fromBlock":hex(b),"toBlock":hex(to)}],retries=1)
            return [{"kind":tag,"block":int(l["blockNumber"],16),"tx":l["transactionHash"],
                     "role":l["topics"][1],"account":"0x"+l["topics"][2][-40:],
                     "sender":"0x"+l["topics"][3][-40:] if len(l["topics"])>3 else None} for l in logs]
        except Exception as e:
            time.sleep(2.0*(i+1))
    raise RuntimeError(f"failed {addr} {b}-{to}")

def scan(url, addr, a, b, step):
    out=[]; cur=a
    while cur<=b:
        to=min(cur+step-1,b)
        for topic,tag in [(T_GRANT,"GRANT"),(T_REVOKE,"REVOKE")]:
            out += one(url,addr,cur,to,topic,tag)
        cur=to+1; time.sleep(0.5)
    return out

res={}
jobs=[
  ("sonic_live_genesis","0x97f91Ca15ce342ef92b6CA9673F5D5B44528bFa1",SONIC,16870000,16883000,49999),
  ("sonic_gen2_genesis","0xf770b76c5646799948b700188a255bdc890f3bf9",SONIC,16878000,16883000,49999),
  ("sonic_gen3_genesis","0xd664dc6b04e68bb4044d2d2997d0ca6308aa63e9",SONIC,16880000,16883000,49999),
  ("hl_acl_deploy","0x7c3396AC1306507040CE338c8b7f99C9540FB3e2",HL,3059000,3061000,999),
  ("hl_acl_may","0x7c3396AC1306507040CE338c8b7f99C9540FB3e2",HL,3567000,3583000,999),
]
for name,addr,url,a,b,step in jobs:
    try:
        ev=scan(url,addr,a,b,step)
        res[name]={"address":addr,"from":a,"to":b,"events":ev}
        print(f"== {name}: {len(ev)} events", flush=True)
        for e in ev: print(f"   {e['kind']} block={e['block']} role={e['role'][:18]}.. account={e['account']}", flush=True)
    except Exception as e:
        res[name]={"address":addr,"err":str(e)[:200]}
        print(f"== {name} ERR {str(e)[:160]}", flush=True)
json.dump(res,open("raw/acl_role_events_genesis.json","w"),indent=2)
