#!/usr/bin/env python3
import json, urllib.request
RPC="https://flare-api.flare.network/ext/C/rpc"
def batch(calls):
    req=urllib.request.Request(RPC,data=json.dumps(calls).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req,timeout=60))
def a(x): return x.lower().replace("0x","").rjust(64,"0")
def i(x): return hex(x)[2:].rjust(64,"0")
BANK="0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059"
OTHER="0x90679234FE693B39BFdf5642060Cb10571Adc59b"
WFLR="0x1d80c49bbbcd1c0911346656b529df9e5c2f783d"
calls=[]; labels=[]
def add(to,data,label):
    calls.append({"jsonrpc":"2.0","id":len(calls)+1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
    labels.append(label)
views=[("totalSupply()","0x18160ddd"),("buyPrice()","0x8620410b"),("sellPrice()","0x4b750334"),
("onlyAmbassadors()","0x27defa1f"),("dividendGrowthX64()","0x2559ad20"),("unclaimedDividendTotal()","0xfc5267df"),
("unclaimedTeamFees()","0xdb2609f4"),("unclaimedFeeReceiverFees()","0xa5789008"),("teamAddress()","0x1c75f085"),
("feeReceiverAddress()","0xf481e863"),("delegator()","0xce9b7930"),("autoClaimTsoRewards()","0xa3b67bc9"),
("nextClaimEpoch()","0x96137390"),("nextClaimMonth()","0xc35992bc")]
for n,s in views:
    add(BANK,s,"bank."+n); add(OTHER,s,"other."+n)
for who in [BANK,OTHER,WFLR,"0x0000000000000000000000000000000000000000"]:
    add(BANK,"0x70a08231"+a(who),"bank.balanceOf("+who[:10]+")")
for who in [BANK,OTHER]:
    add(WFLR,"0x70a08231"+a(who),"wflr.balanceOf("+who[:10]+")")
add(WFLR,"0x18160ddd","wflr.totalSupply()")
add(WFLR,"0x313ce567","wflr.decimals()")
# roles
from subprocess import check_output
def keccak(x): return check_output(["cast","keccak",x]).decode().strip()
role_admin=keccak("BANK_ADMIN"); role_amb=keccak("AMBASSADOR")
add(BANK,"0x248a9ca3"+"00"*32,"bank.getRoleAdmin(0x0)")
add(BANK,"0x248a9ca3"+role_admin[2:],"bank.getRoleAdmin(BANK_ADMIN)")
add(BANK,"0x248a9ca3"+role_amb[2:],"bank.getRoleAdmin(AMBASSADOR)")
holders=[BANK,OTHER,"0x0000000000000000000000000000000000000000"]
# team/feeReceiver read later
rep=batch(calls)
res={}
for c,r in zip(calls,rep):
    idx=c["id"]-1
    res[labels[idx]]=r.get("result", "ERR:"+str(r.get("error",{}).get("message","?"))[:60])
for k,v in res.items():
    print(f"{k:42s} {v}")
json.dump(res,open("state2.json","w"),indent=1)
# decode some
def dec_uint(h): return int(h,16) if h and h!="0x" and not h.startswith("ERR") else None
print("--- decoded")
print("bank.totalSupply", dec_uint(res["bank.totalSupply()"])/1e18)
print("bank.buyPrice", dec_uint(res["bank.buyPrice()"])/1e18, "FLR/token")
print("bank.sellPrice", dec_uint(res["bank.sellPrice()"])/1e18, "FLR/token")
print("wflr.balanceOf(bank)", dec_uint(res["wflr.balanceOf(0x194726F6)"])/1e18)
if "wflr.balanceOf(0x90679234)" in res: print("wflr.balanceOf(other)", dec_uint(res["wflr.balanceOf(0x90679234)"])/1e18)
print("teamAddress", res["bank.teamAddress()"])
print("feeReceiver", res["bank.feeReceiverAddress()"])
print("delegator", res["bank.delegator()"])
