#!/usr/bin/env python3
"""Chunked RoleGranted/RoleRevoked scan for ACL windows."""
import json, sys, time
sys.path.insert(0,'.')
from lib import rpc, SONIC, HL

T_GRANT = "0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d"
T_REVOKE= "0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b"

def scan_window(url, addr, start, end, step):
    out=[]
    b=start
    while b<=end:
        to=min(b+step-1,end)
        for topic,tag in [(T_GRANT,"GRANT"),(T_REVOKE,"REVOKE")]:
            for attempt in range(4):
                try:
                    logs=rpc(url,"eth_getLogs",[{"address":addr,"topics":[topic],"fromBlock":hex(b),"toBlock":hex(to)}],retries=3)
                    break
                except Exception as e:
                    if attempt==3: raise
                    time.sleep(1.5*(attempt+1))
            for l in logs:
                out.append({"kind":tag,"block":int(l["blockNumber"],16),"tx":l["transactionHash"],
                            "role":l["topics"][1],"account":"0x"+l["topics"][2][-40:],
                            "sender":"0x"+l["topics"][3][-40:] if len(l["topics"])>3 else None})
        b=to+1
        time.sleep(0.4)
    return out

if __name__=="__main__":
    res={}
    windows = [
      ("sonic_live_acl","0x97f91Ca15ce342ef92b6CA9673F5D5B44528bFa1",SONIC,16880000,16900000,49999),
      ("sonic_live_acl_may","0x97f91Ca15ce342ef92b6CA9673F5D5B44528bFa1",SONIC,25350000,25800000,49999),
      ("sonic_gen2_acl","0xf770b76c5646799948b700188a255bdc890f3bf9",SONIC,16880000,16920000,49999),
      ("sonic_gen3_acl","0xd664dc6b04e68bb4044d2d2997d0ca6308aa63e9",SONIC,16880000,16920000,49999),
      ("hl_acl_deploy","0x7c3396AC1306507040CE338c8b7f99C9540FB3e2",HL,3059000,3061000,999),
      ("hl_acl_may","0x7c3396AC1306507040CE338c8b7f99C9540FB3e2",HL,3550000,3585000,999),
    ]
    for name,addr,url,a,b,step in windows:
        try:
            ev=scan_window(url,addr,a,b,step)
            res[name]={"address":addr,"from":a,"to":b,"events":ev}
            print(f"== {name}: {len(ev)} events")
        except Exception as e:
            res[name]={"address":addr,"err":str(e)[:200]}
            print(f"== {name} ERR {str(e)[:160]}")
    json.dump(res,open("raw/acl_role_events_chunked.json","w"),indent=2)
    for name,d in res.items():
        if "events" not in d: continue
        print(f"\n=== {name} ===")
        for e in d["events"]:
            print(f"{e['kind']} block={e['block']} role={e['role'][:20]}.. account={e['account']}")
