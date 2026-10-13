#!/usr/bin/env python3
"""Probe live Voter/Minter functions and simulate permissionless gates (eth_call, read-only)."""
import json, urllib.request, subprocess

RPC = "https://mainnet.era.zksync.io"
VOTER = "0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A"
MINTER = "0x8f0b4B3e211c84061ab5959Bd3D49C6B3EeC1d7D"
ESCROW = "0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F"
FROM = "0x0000000000000000000000000000000000000BAD"

def selector(sig):
    return subprocess.run(["cast","sig",sig],capture_output=True,text=True).stdout.strip()

def call(to, sig, args_hex="", frm=FROM, gas=None):
    data = selector(sig)+args_hex
    obj = {"from":frm,"to":to,"data":data}
    if gas: obj["gas"] = hex(gas)
    payload={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[obj,"latest"]}
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            d=json.loads(r.read())
        if "result" in d: return ("OK", d["result"][:80])
        e=d.get("error",{})
        # try decode Error(string)
        data = e.get("data","")
        msg=""
        if isinstance(data,str) and data.startswith("0x08c379a0") and len(data)>200:
            ln=int(data[2+64:2+128],16); msg=bytes.fromhex(data[2+128:2+128+2*ln]).decode('utf8','replace')
        return ("REVERT", msg or str(e.get("message",""))[:70])
    except Exception as e:
        return ("ERR", str(e)[:70])

def addr(a): return a[2:].lower().zfill(64)
def uint(n): return hex(n)[2:].zfill(64)

print("== Voter read state")
for sig,args in [("length()",""),("totalWeight()",""),("minter()",""),("factory()",""),("governor()",""),
                 ("index()",""),("gaugeIndex(address)",addr(VOTER)),("weights(address)",addr(VOTER)),
                 ("claimable(address)",addr(VOTER)),("lastDistributed(address)",addr(VOTER)),
                 ("isWhitelisted(address)",addr(VOTER)),("isGauge(address)",addr(VOTER)),
                 ("isAlive(address)",addr(VOTER)),("gauges(address)",addr("0xcd52cbc975fbb802f82a1f92112b1250b5a997df"))]:
    st,res=call(VOTER,sig,args)
    print(f"  {sig:30} {st:7} {res}")

print("== Voter permissionless simulations from 0xBAD")
st,res=call(VOTER,"createGauge(address)",addr("0xcd52cbc975fbb802f82a1f92112b1250b5a997df"),gas=3000000)
print("  createGauge(existing pool) ->",st,res)
st,res=call(VOTER,"createGauge(address)",addr("0x000000000000000000000000000000000000dead"),gas=3000000)
print("  createGauge(random) ->",st,res)
st,res=call(VOTER,"distribute(address[])",uint(0x20)+uint(1)+addr("0xb3120Ad6C3285fc4E422581d9ad003277802CC47"),gas=3000000)
print("  distribute([gauge]) ->",st,res)
st,res=call(VOTER,"claimBribes(address[],address[][],uint256)",uint(0x60)+uint(0xa0)+uint(1)+uint(0)+uint(0),gas=3000000)
print("  claimBribes(empty) ->",st,res)

print("== Minter state")
for sig,args in [("active_period()",""),("weekly()",""),("_velocore()",""),("velocore()",""),("_total_supply()",""),
                 ("total_supply()",""),("voter()",""),("owner()",""),("WEEK()",""),("lastMint()","")]:
    st,res=call(MINTER,sig,args)
    print(f"  {sig:20} {st:7} {res}")
st,res=call(MINTER,"update_period()",gas=3000000)
print("  update_period() ->",st,res)

print("== VotingEscrow state")
for sig,args in [("token()",""),("name()",""),("totalSupply()",""),("locked(uint256)",uint(1)),
                 ("ownerOf(uint256)",uint(1)),("supply()",""),("decimals()",""),("minter()","")]:
    st,res=call(ESCROW,sig,args)
    print(f"  {sig:20} {st:7} {res}")
