import json, os, urllib.request, sys

DRPC="https://base.drpc.org"; DKEY=os.environ.get("DRPC_API_KEY","")
INF="https://base-mainnet.infura.io/v3/"+os.environ.get("INFURA_API_KEY","")
ENDPOINTS=[]
for u,h in [(DRPC,{"X-API-Key":DKEY}),(INF,{}),("https://base-rpc.publicnode.com",{}),("https://mainnet.base.org",{})]:
    if u: ENDPOINTS.append((u,h))
import time
def rpc(method, params):
    last=None
    for attempt in range(3):
        for (url,hdrs) in ENDPOINTS:
            try:
                hh={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"}; hh.update(hdrs)
                req=urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(), headers=hh)
                return json.load(urllib.request.urlopen(req, timeout=45))
            except Exception as e:
                last=e
                time.sleep(0.5*attempt)
    raise last

BLK="latest"
def call(to, data, frm, blk=BLK, gas="0x1c9c380"):
    p=[{"from":frm,"to":to,"data":data,"gas":gas}]
    if blk: p.append(blk)
    r=rpc("eth_call",p)
    if "result" in r: return ("OK", r["result"])
    err=r.get("error",{})
    d=err.get("data")
    msg=err.get("message","")
    if isinstance(d,dict): d=d.get("data") or str(d)
    return ("REVERT", (d or msg))

def dec(res):
    st,val=res
    if st=="OK": return "OK ret="+str(val)[:74]
    v=str(val)
    if v.startswith("0x08c379a0") and len(v)>=138:
        try:
            raw=bytes.fromhex(v[2:])
            ln=int.from_bytes(raw[36:68],"big")
            return "REVERT:Error(\""+raw[68:68+ln].decode(errors="replace")+"\")"
        except Exception: pass
    if v.startswith("0x4e487b71"): return "REVERT:Panic"
    return "REVERT:"+v[:80]

V="0xD1895f2019c2152FC2b9022D57f19198c4CFCABC"
VIMP="0x209d85f0ed5393f8f772d46bf889c251132a68bb"
H="0xcdFE91301356da873562EF513828a60dba1F569d"
HIMP="0x5d7a38144b4d17f47a22e3d0987523cd68b43310"
SIB="0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23"
SIMP="0x67ed441b2444e055376F4acaBddA969F8926e4EA"
ATT="0x0B5126e1bc27C0de77e02e97945760A674EdB034"
WEOA="0x3E68796A3A43a0a6a2B40Bc9ABF8e372e7a7Ff36"
FRESH="0x2222222222222222222222222222222222222222"
FRESH2="0x3333333333333333333333333333333333333333"
AWETH="0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7"
WETH="0x4200000000000000000000000000000000000006"
AERO="0x940181a94A35A4569E4529A3CDfB74e38FD98631"

def pad(a): return "0"*24+a[2:].lower()
def u(x): return format(x,"064x")

results=[]
def probe(label,to,data,frm):
    res=call(to,data,frm)
    line=f"{label:52s} | from={frm[:10]} | {dec(res)}"
    print(line)
    results.append({"label":label,"to":to,"data":data,"from":frm,"result":line.split(" | ")[-1]})
    return res

print("### whitelist state")
for who,name in [(H,"helper"),(WEOA,"whitelistEOA"),(FRESH,"fresh"),(ATT,"attackerEOA"),(SIB,"sibling")]:
    print(" whitelist("+name+") =",dec(call(V,"0x9b19251a"+pad(who),FRESH)))

print("\n### HELPER impl functions from FRESH")
probe("helper.4cf8513b() view","H:0x4cf8513b",FRESH) if False else None
probe("helper.vault/getter 4cf8513b()",H,"0x4cf8513b",FRESH)
probe("helper.cb984317(asset,1e18)",H,"0xcb984317"+pad(AWETH)+u(10**18),FRESH)
probe("helper.cb984317(weth,1e18)",H,"0xcb984317"+pad(WETH)+u(10**18),FRESH)
probe("helper.debd4ffc(0,0) view",H,"0xdebd4ffc"+u(0)+u(0),FRESH)
probe("helper.debd4ffc(1e18,1e18) view",H,"0xdebd4ffc"+u(10**18)+u(10**18),FRESH)
probe("helper.__withdraw(aweth,1e18)",H,"0x9a39f8dd"+pad(AWETH)+u(10**18),FRESH)
probe("helper.owner()",H,"0x8da5cb5b",FRESH)
probe("helper.initialize()",H,"0x8129fc1c",FRESH)
probe("helper.renounceOwnership()",H,"0x715018a6",FRESH)
probe("helper.transferOwnership(fresh)",H,"0xf2fde38b"+pad(FRESH),FRESH)

print("\n### HELPER impl functions from ATTACKER (control)")
probe("helper.cb984317(asset,1e18) [attacker]",H,"0xcb984317"+pad(AWETH)+u(10**18),ATT)
probe("helper.debd4ffc(1e18,1e18) view [attacker]",H,"0xdebd4ffc"+u(10**18)+u(10**18),ATT)
probe("helper.__withdraw(aweth,0) [attacker]",H,"0x9a39f8dd"+pad(AWETH)+u(0),ATT)

print("\n### HELPER impl address DIRECT from FRESH (uninitialized state)")
for sel,label,args in [("0x4cf8513b","vault()",""),("0xcb984317","cb984317(aweth,1)","00"*12+"d4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7".lower()+u(1)),("0xdebd4ffc","__redeem(0,0)","0"*64*2),("0x9a39f8dd","__withdraw(aweth,1)","00"*12+"d4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7".lower()+u(1)),("0x8129fc1c","initialize()",""),("0x8da5cb5b","owner()","")]:
    probe("HIMP."+label,HIMP,sel+args,FRESH)

print("\n### VAULT impl functions from FRESH")
probe("vault.pool() view",V,"0x16f0115b",FRESH)
probe("vault.minToken(aweth) view",V,"0x23bb1115"+pad(AWETH),FRESH)
probe("vault.getUserReserveData(aweth,fresh) view",V,"0x28dd2d01"+pad(AWETH)+pad(FRESH),FRESH)
probe("vault.aToken(aweth) view",V,"0x3615fe4e"+pad(AWETH),FRESH)
probe("vault.__setWhitelist__(fresh,true)",V,"0x38edc837"+pad(FRESH)+u(1),FRESH)
probe("vault.getReserveConfigurationData(aweth) view",V,"0x3e150141"+pad(AWETH),FRESH)
probe("vault.minHealth() view",V,"0x455166a2",FRESH)
probe("vault.debtToken(aweth) view",V,"0x492fffc7"+pad(AWETH),FRESH)
probe("vault.4abb8b6f(aweth)",V,"0x4abb8b6f"+pad(AWETH),FRESH)
probe("vault.repay(aweth,1,2,fresh)",V,"0x573ade81"+pad(AWETH)+u(1)+u(2)+pad(FRESH),FRESH)
probe("vault.supply(weth,1,fresh,0)",V,"0x617ba037"+pad(WETH)+u(1)+pad(FRESH)+u(0),FRESH)
probe("vault.withdraw(aweth,1,fresh)",V,"0x69328dec"+pad(AWETH)+u(1)+pad(FRESH),FRESH)
probe("vault.698442db(aweth,fresh,1,[]) ",V,"0x698442db"+pad(AWETH)+pad(FRESH)+u(1)+u(128)+u(0),FRESH)
probe("vault.6b711cc9(aweth,1)",V,"0x6b711cc9"+pad(AWETH)+u(1),FRESH)
probe("vault.renounceOwnership()",V,"0x715018a6",FRESH)
probe("vault.76309d0e(aweth,1)",V,"0x76309d0e"+pad(AWETH)+u(1),FRESH)
probe("vault.owner() view",V,"0x8da5cb5b",FRESH)
probe("vault.whitelist(fresh) view",V,"0x9b19251a"+pad(FRESH),FRESH)
probe("vault.supplyAmount(aweth,fresh) view",V,"0x9c61322d"+pad(AWETH)+pad(FRESH),FRESH)
probe("vault.borrow(aweth,1,2,0,fresh)",V,"0xa415bcad"+pad(AWETH)+u(1)+u(2)+u(0)+pad(FRESH),FRESH)
probe("vault.initialize(pool?)",V,"0xc4d66de8"+pad("0xA238Dd80C259a72e81d7e4664a9801593F98d1c5"),FRESH)
probe("vault.d2b2de5b(aweth,1)",V,"0xd2b2de5b"+pad(AWETH)+u(1),FRESH)
probe("vault.borrowAmount(aweth,fresh) view",V,"0xdb35b25f"+pad(AWETH)+pad(FRESH),FRESH)
probe("vault.transferOwnership(fresh)",V,"0xf2fde38b"+pad(FRESH),FRESH)

print("\n### VAULT proxy special")
probe("vault.admin()",V,"0xf851a440",FRESH)
probe("vault.implementation()",V,"0x5c60da1b",FRESH)
probe("vault.upgradeTo(fresh)",V,"0x3659cfe6"+pad(FRESH),FRESH)
probe("vault.changeAdmin(fresh)",V,"0x8f283970"+pad(FRESH),FRESH)
probe("vault empty calldata",V,"0x",FRESH)
probe("vault unknown selector",V,"0xdeadbeef",FRESH)
probe("vault.admin() FROM ADMIN",V,"0xf851a440","0x490ca969b43b1ab869b5959a7b3919cc2c37c4e6")

json.dump(results, open("matrix_results.json","w"), indent=1)
print("\nWROTE matrix_results.json (%d rows)"%len(results))
