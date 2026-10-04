#!/usr/bin/env python3
"""Roles & authority check at pinned block. Raw evidence to raw/sonic_roles.json"""
import json, sys
sys.path.insert(0,'.')
from lib import rpc, call, storage, balance, blocknum, SONIC

BLK = int(sys.argv[1]) if len(sys.argv)>1 else blocknum(SONIC)
ACL    = "0x97f91Ca15ce342ef92b6CA9673F5D5B44528bFa1"
AP     = "0x0F69b45c5f7f54C4064D38a73b5BB74c7bda8A58"
POOL   = "0x648Abc6Fd9D69F7B4b6514B3b777359C029Dfe67"
CONF   = "0x01171d5be2734Dc4eB8E6738783AD1Bd88A49Add"
ORACLE = "0x5D30854B3172bD227D8ef492858FFCBc4fe3F6FE"

def pad(x):
    if x.startswith("0x"): x = x[2:]
    return x.rjust(64,"0")

ROLES = {
 "DEFAULT_ADMIN_ROLE":"0x"+"00"*32,
 "POOL_ADMIN": "0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b",
 "EMERGENCY_ADMIN":"0x5c91514091af31f62f596a314af7d5be40146b2f2355969392f055e12e0982fb",
 "RISK_ADMIN":"0x8aa855a911518ecfbe5bc3088c8f3dda7badf130faaf8ace33fdc33828e18167",
 "BRIDGE":"0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278",
 "ASSET_LISTING_ADMIN":"0x19c860a63258efbd0ecb7d55c626237bf5c2044c26c073390b74f0c13c857433",
 "FLASH_BORROWER":"0x939b8dfb57ecef2aea54a93a15e86768b9d4089f1ba61c245e6ec980695f4ca4",
 "LIQUIDATOR_ROLE":"0x5e17fc5225d4a099df75359ce1f405503ca79498a8dc46a7d583235a0ee45c16",
 "EMISSION_MANAGER":"0x0178ef1edee9408b9148e43c7402964baa5d7066a35d0ff56e2596c8e1dc0f67",
}
ACTORS = {
 "rogue_deployer":"0xc0454e29835479ee80d6f42965a16dcee9bfd868",
 "provider_owner_and_acl_admin":"0x9b644a58713f5731be089620ec61bdb1075cb3f5",
 "addr_40c79ebc":"0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
 "revoker_admin_0xe82e":"0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4",
 "zero":"0x0000000000000000000000000000000000000000",
 "drain_target_5149a769":"0x5149a7696188f083297281d10293a20476252cdd",
 "aTokenUSDC_proxy":"0xd49f01eb40e526342bf29f87881bc8689305bfaa",
}
out = {"chain":"sonic","chain_id":146,"block":BLK,"acl_manager":ACL,
       "roles":{k:v for k,v in ROLES.items()},
       "checks":{}, "isX":{}, "logs":{}}

for an, a in ACTORS.items():
    out["checks"][an] = {"address":a}
    for rn, r in ROLES.items():
        res = call(SONIC, ACL, "0x91d14854"+r[2:].rjust(64,"0")+pad(a), BLK)
        out["checks"][an][rn] = bool(int(res,16))
    for fname, fsel in [("isPoolAdmin","0x7be53ca1"),("isEmergencyAdmin","0x2500f2b6"),
                        ("isRiskAdmin","0x674b5e4d"),("isBridge","0x726600ce"),
                        ("isAssetListingAdmin","0x13ee32e0"),("isFlashBorrower","0xfa50f297"),
                        ("isLiquidator","0x529a356f")]:
        try:
            out["isX"].setdefault(an,{})[fname] = bool(int(call(SONIC, ACL, fsel+pad(a), BLK),16))
        except Exception as e:
            out["isX"].setdefault(an,{})[fname] = f"revert/err ({str(e)[:60]})"

# role admins
out["role_admin"] = {}
for rn,r in ROLES.items():
    if rn=="DEFAULT_ADMIN_ROLE": continue
    out["role_admin"][rn] = "0x"+call(SONIC, ACL, "0x248a9ca3"+r[2:].rjust(64,"0"), BLK)[-40:]

# provider owner / acl admin / pending owner
out["provider"] = {
  "owner": "0x"+call(SONIC, AP, "0x8da5cb5b", BLK)[-40:],
}
# code presence for key EOAs/contracts
out["is_contract"] = {}
for an,a in list(ACTORS.items())+[("pool",POOL),("provider",AP),("configurator",CONF),("oracle",ORACLE)]:
    code = rpc(SONIC,"eth_getCode",[a, hex(BLK)])
    out["is_contract"][an] = {"address":a,"is_contract": code not in ("0x","0x0"), "code_len": (len(code)-2)//2}

# EIP-1967 impl/admin slots for proxies
SLOTS = {
 "impl":"0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
 "admin":"0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
}
for pn, p in [("pool_proxy",POOL),("configurator_proxy",CONF),("aTokenUSDC", "0xd49f01eb40e526342bf29f87881bc8689305bfaa"),("vDebtUSDC","0x75af219905870d813168cb2c89004cb78e1a207b")]:
    out.setdefault("proxy_slots",{})[pn]={"address":p}
    for sn,s in SLOTS.items():
        out["proxy_slots"][pn][sn]="0x"+storage(SONIC,p,int(s,16),BLK)[-40:]
# admin() view on proxies (Aave proxies expose admin())
for pn,p in [("pool_proxy",POOL),("configurator_proxy",CONF),("aTokenUSDC","0xd49f01eb40e526342bf29f87881bc8689305bfaa")]:
    try:
        out["proxy_slots"][pn]["admin_view"]="0x"+call(SONIC,p,"0xf851a440",BLK)[-40:]
    except Exception as e:
        out["proxy_slots"][pn]["admin_view"]=f"ERR {e}"

with open("raw/sonic_roles.json","w") as f:
    json.dump(out,f,indent=2)

for an,d in out["checks"].items():
    held=[k for k,v in d.items() if v and k!="address"]
    print(an, d["address"], "HELD:", held if held else "none")
print("provider owner:", out["provider"]["owner"])
print("proxy slots:", json.dumps(out["proxy_slots"],indent=1))
