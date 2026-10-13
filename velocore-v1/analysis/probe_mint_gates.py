#!/usr/bin/env python3
"""Why does update_period/distribute revert? Check VC mint gates."""
import json, urllib.request, subprocess

RPC = "https://mainnet.era.zksync.io"
VC = "0x85D84c774CF8e9fF85342684b0E795Df72A24908"
MINTER = "0x8f0b4B3e211c84061ab5959Bd3D49C6B3EeC1d7D"
VOTER = "0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A"

def selector(sig):
    return subprocess.run(["cast","sig",sig],capture_output=True,text=True).stdout.strip()

def call(to, sig, args_hex="", frm="0x0000000000000000000000000000000000000BAD", gas=None, value=None):
    data = selector(sig)+args_hex
    obj = {"from":frm,"to":to,"data":data}
    if gas: obj["gas"] = hex(gas)
    if value: obj["value"] = hex(value)
    payload={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[obj,"latest"]}
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            d=json.loads(r.read())
        if "result" in d: return ("OK", d["result"][:90])
        e=d.get("error",{})
        data = e.get("data","")
        msg=""
        if isinstance(data,str) and data.startswith("0x08c379a0") and len(data)>200:
            ln=int(data[2+64:2+128],16); msg=bytes.fromhex(data[2+128:2+128+2*ln]).decode('utf8','replace')
        return ("REVERT", msg or str(e.get("message",""))[:80])
    except Exception as e:
        return ("ERR", str(e)[:80])

def addr(a): return a[2:].lower().zfill(64)
def uint(n): return hex(n)[2:].zfill(64)

print("== VC token")
for sig in ["name()","symbol()","owner()","minter()","pendingOwner()","totalSupply()","cap()","MAX_SUPPLY()","decimals()"]:
    st,res = call(VC, sig)
    print(f"  {sig:16} {st:7} {res}")

print("== simulate VC.mint from MINTER (read-only)")
st,res = call(VC, "mint(address,uint256)", addr("0x000000000000000000000000000000000000dEaD")+uint(1), frm=MINTER)
print("  mint(dead,1) from minter ->", st, res)
st,res = call(VC, "mint(address,uint256)", addr("0x000000000000000000000000000000000000dEaD")+uint(1), frm="0x0000000000000000000000000000000000000BAD")
print("  mint(dead,1) from random ->", st, res)

print("== Minter more")
for sig in ["weekly()","active_period()","velocore()","_velocore()","voter()","governor()","owner()","WEEK()","initializer()","update_period()","updatePeriod()","mint()"]:
    st,res = call(MINTER, sig)
    print(f"  {sig:16} {st:7} {res}")
st,res = call(MINTER, "update_period()", gas=5000000)
print("  update_period() gas sim ->", st, res)

print("== Voter distribute reasons")
# gauge for pool0
st,res = call(VOTER, "gauges(address)", addr("0xcD52cbc975fbB802F82A1F92112b1250b5a997Df"))
print("  gauges(pool0) ->", st, res)
g = "0x" + res[-40:] if st=="OK" else None
if g:
    st,res = call(VOTER, "distribute(address[])", uint(0x20)+uint(1)+addr(g), gas=5000000)
    print(f"  distribute([{g[:10]}]) ->", st, res)
    st,res = call(VOTER, "isAlive(address)", addr(g))
    print("  isAlive(gauge) ->", st, res)
    st,res = call(VOTER, "claimable(address)", addr(g))
    print("  claimable(gauge) ->", st, res)
    st,res = call(VOTER, "weights(address)", addr(g))
    print("  weights(gauge) ->", st, res)
    st,res = call(VOTER, "supplyIndex(address)", addr(g))
    print("  supplyIndex(gauge) ->", st, res)
