#!/usr/bin/env python3
"""RoleGranted/RoleRevoked history for ACLManagers (Sonic live+gen2+gen3, HL)."""
import json, sys
sys.path.insert(0,'.')
from lib import rpc, blocknum, SONIC, HL

ROLE_GRANTED = "0x2f2ff15dcb6d86b5b0fe5b16e57b5e82e6ef70d6a7b5b6ea4a6d5c2f6f8e2f0e"  # placeholder, computed below
import hashlib
# compute topics via eth utils? use known: keccak("RoleGranted(bytes32,address,address)")
# cast keccak RoleGranted
# We'll pass topics computed by cast externally; here hardcode after checking:

def get_logs(rpc_url, address, topic0, frm, to):
    return rpc(rpc_url, "eth_getLogs", [{"address":address,"topics":[topic0],"fromBlock":hex(frm),"toBlock":hex(to)}], retries=4)

if __name__ == "__main__":
    import subprocess
    t_grant = subprocess.check_output(["cast","keccak","RoleGranted(bytes32,address,address)"]).decode().strip()
    t_revoke = subprocess.check_output(["cast","keccak","RoleRevoked(bytes32,address,address)"]).decode().strip()
    print("RoleGranted topic:", t_grant)
    print("RoleRevoked topic:", t_revoke)
    out={}
    targets = [
        ("sonic_live_acl","0x97f91Ca15ce342ef92b6CA9673F5D5B44528bFa1",SONIC,16890000,blocknum(SONIC)),
        ("sonic_gen2_acl","0xf770b76c5646799948b700188a255bdc890f3bf9",SONIC,16890000,blocknum(SONIC)),
        ("sonic_gen3_acl","0xd664dc6b04e68bb4044d2d2997d0ca6308aa63e9",SONIC,16890000,blocknum(SONIC)),
        ("hl_acl","0x7c3396AC1306507040CE338c8b7f99C9540FB3e2",HL,2900000,blocknum(HL)),
    ]
    for name,addr,rpc_url,start,end in targets:
        try:
            logs = get_logs(rpc_url, addr, t_grant, start, end) + get_logs(rpc_url, addr, t_revoke, start, end)
            simplified=[]
            for l in logs:
                simplified.append({"block":int(l["blockNumber"],16),"tx":l["transactionHash"],
                                   "topic0":l["topics"][0],
                                   "role":l["topics"][1] if len(l["topics"])>1 else None,
                                   "account":"0x"+l["topics"][2][-40:] if len(l["topics"])>2 else None,
                                   "sender":"0x"+l["topics"][3][-40:] if len(l["topics"])>3 else None})
            out[name]={"address":addr,"granted":t_grant,"revoked":t_revoke,"n":len(simplified),"logs":simplified}
            print(name, addr, "events:", len(simplified))
        except Exception as e:
            out[name]={"address":addr,"err":str(e)[:200]}
            print(name, addr, "ERR", str(e)[:200])
    json.dump(out, open("raw/acl_role_events.json","w"), indent=2)
    for name,d in out.items():
        if "logs" not in d: continue
        print(f"\n=== {name} ===")
        for l in d["logs"]:
            kind = "GRANT" if l["topic0"]==d["granted"] else "REVOKE"
            print(f"{kind} block={l['block']} role={l['role'][:18]}.. account={l['account']}")
