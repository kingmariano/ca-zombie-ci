#!/usr/bin/env python3
"""HL roles + drain decode + gate simulation. Raw evidence."""
import json, sys
sys.path.insert(0,'.')
from lib import rpc, call, balance, storage, blocknum, HL

BLK = int(sys.argv[1]) if len(sys.argv)>1 else blocknum(HL)
ACL = "0x7c3396AC1306507040CE338c8b7f99C9540FB3e2"
AP  = "0xa717D758D8776121aba09cDE137Fea6a917bbe0d"
POOL= "0x4b0B2f51596c52ebf89c1109882b32FCE50e8F63"

def pad(x):
    if x.startswith("0x"): x=x[2:]
    return x.rjust(64,"0")

ROLES = {
 "DEFAULT_ADMIN_ROLE":"0x"+"00"*32,
 "POOL_ADMIN":"0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b",
 "EMERGENCY_ADMIN":"0x5c91514091af31f62f596a314af7d5be40146b2f2355969392f055e12e0982fb",
 "RISK_ADMIN":"0x8aa855a911518ecfbe5bc3088c8f3dda7badf130faaf8ace33fdc33828e18167",
 "BRIDGE":"0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278",
 "ASSET_LISTING_ADMIN":"0x19c860a63258efbd0ecb7d55c626237bf5c2044c26c073390b74f0c13c857433",
 "FLASH_BORROWER":"0x939b8dfb57ecef2aea54a93a15e86768b9d4089f1ba61c245e6ec980695f4ca4",
 "LIQUIDATOR_ROLE":"0x5e17fc5225d4a099df75359ce1f405503ca79498a8dc46a7d583235a0ee45c16",
 "EMISSION_MANAGER":"0x0178ef1edee9408b9148e43c7402964baa5d7066a35d0ff56e2596c8e1dc0f67",
}
ACTORS = {
 "hl_owner_deployer_eoa":"0x5b8a72bb69Fe0e766562c2BCD3b6EdbF21360b11",
 "rogue_sonic_deployer":"0xc0454e29835479ee80d6f42965a16dcee9bfd868",
 "safe_9b644a":"0x9b644a58713f5731be089620ec61bdb1075cb3f5",
 "revoker_e82e":"0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4",
 "addr_40c79e":"0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
 "addr_5149a7":"0x5149a7696188f083297281d10293a20476252cdd",
 "zero":"0x0000000000000000000000000000000000000000",
}
out={"chain":"hyperevm","chain_id":999,"block":BLK,"acl":ACL,"checks":{},"isX":{},"drain_txs":{}}
for an,a in ACTORS.items():
    out["checks"][an]={"address":a}
    for rn,r in ROLES.items():
        try: out["checks"][an][rn]=bool(int(call(HL,ACL,"0x91d14854"+r[2:].rjust(64,"0")+pad(a),BLK),16))
        except Exception as e: out["checks"][an][rn]=f"ERR {str(e)[:60]}"
    for fname,fsel in [("isPoolAdmin","0x7be53ca1"),("isEmergencyAdmin","0x2500f2b6"),
                       ("isRiskAdmin","0x674b5e4d"),("isBridge","0x726600ce"),
                       ("isAssetListingAdmin","0x13ee32e0"),("isFlashBorrower","0xfa50f297")]:
        try: out["isX"].setdefault(an,{})[fname]=bool(int(call(HL,ACL,fsel+pad(a),BLK),16))
        except Exception as e: out["isX"].setdefault(an,{})[fname]=f"revert({str(e)[:40]})"

# provider owner
out["provider_owner"]="0x"+call(HL,AP,"0x8da5cb5b",BLK)[-40:]
out["provider_getACLAdmin"]="0x"+call(HL,AP,"0x"+'0ef32c1c',BLK)[-40:] if False else None

# drain txs decode (known hashes)
DRAIN={
 "0x26095510aae7cec995b1e782be127a2db80899c6f8b845c04495a1dbb0349a37":"WHYPE",
 "0x51571266f602b7e25e8ed1a144c05ed29756983d3f978277b4f5079b8e673a7f":"wstHYPE",
}
TRANSFER="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
for h,label in DRAIN.items():
    try:
        tx=rpc(HL,"eth_getTransactionByHash",[h]); rc=rpc(HL,"eth_getTransactionReceipt",[h])
        inp=tx["input"]
        e={"block":int(tx["blockNumber"],16),"selector":inp[:10],
           "arg_target":"0x"+inp[10:74][-40:],"arg_amount":int(inp[74:138],16),
           "status":rc["status"],"logs":[]}
        for l in rc["logs"]:
            d={"address":l["address"],"topics":l["topics"],"data":l["data"]}
            if l["topics"] and l["topics"][0].lower()==TRANSFER and len(l["topics"])>=3:
                d["decoded"]={"from":"0x"+l["topics"][1][-40:],"to":"0x"+l["topics"][2][-40:],"value":int(l["data"],16)}
            e["logs"].append(d)
        out["drain_txs"][label]=e
    except Exception as ex:
        out["drain_txs"][label]={"err":str(ex)[:200]}

# gate simulation on both aTokens + pool
sim={}
for label,at in [("WHYPE_atoken","0x6824429DDd4d3cE5Ff50e67e3CC909d7298dc759"),
                 ("wstHYPE_atoken","0x3383e37cad159bb00a56e330ce71d9f24e89a6c4")]:
    data="0x4efecaa5"+"000000000000000000000000"+"000000000000000000000000000000000000dead"+"0000000000000000000000000000000000000000000000000000000000000001"
    for who,frm in [("random","0x1111111111111111111111111111111111111111"),
                    ("pool",POOL),("rogue","0xc0454e29835479ee80d6f42965a16dcee9bfd868"),
                    ("hl_owner_eoa","0x5b8a72bb69Fe0e766562c2BCD3b6EdbF21360b11")]:
        try:
            r=call(HL,at,data,BLK,frm=frm); sim[f"{label}_{who}"]={"result":r[:80]}
        except Exception as e:
            sim[f"{label}_{who}"]={"error":str(e)[:160]}
out["gate_sim"]=sim

with open("raw/hl_roles_and_gate.json","w") as f: json.dump(out,f,indent=2)

for an,d in out["checks"].items():
    held=[k for k,v in d.items() if v is True]
    print(an, d["address"], "HELD:", held if held else "none")
print("provider owner:", out["provider_owner"])
for l,e in out["drain_txs"].items():
    if "err" in e: print(l, e); continue
    print(f"{l}: block={e['block']} target={e['arg_target']} amount={e['arg_amount']} status={e['status']}")
    for lg in e["logs"]:
        if "decoded" in lg: print("   ", lg["address"], lg["decoded"])
for k,v in out["gate_sim"].items():
    print(k, "->", json.dumps(v)[:150])
