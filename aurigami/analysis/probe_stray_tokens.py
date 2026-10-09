#!/usr/bin/env python3
"""Check cToken balances of non-underlying tokens (sweepToken exposure) + membership in dead markets."""
import json, urllib.request
from Crypto.Hash import keccak

RPC="https://mainnet.aurora.dev"
UNIT="0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"
MARKETS={
 "auUSDC":"0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
 "auETH":"0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
 "auWBTC":"0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
 "auUSDT":"0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
 "auDAI":"0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
 "auWNEAR":"0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
 "auSTNEAR":"0x3195949f267702723bc614cAE037cdc8D1E94786",
 "auAURORA":"0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
 "auTRI":"0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
 "auPLY":"0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
 "auUSN":"0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
 "auNEARX":"0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
 "auUSDCNative":"0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
 "auUSDTNative":"0xdDfd0407220026c6566979B5be6A4983d1247a3E",
}
UND={
 "USDC":"0xB12BFcA5A55806AaF64E99521918A4bf0fC40802",
 "WBTC":"0xF4eB217Ba2454613b15dBdea6e5f22276410e89e",
 "USDT":"0x4988a896b1227218e4A686fdE5EabdcAbd91571f",
 "DAI":"0xe3520349F477A5F6EB06107066048508498A291b",
 "WNEAR":"0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d",
 "STNEAR":"0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30",
 "AURORA":"0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79",
 "TRI":"0xFa94348467f64D5A457F75F8bc40495D33c65aBB",
 "PLY_TOK":"0x09C9D464b58d96837f8d8b6f4d9fE4aD408d3A4f",
 "USN":"0x5183e1B1091804BC2602586919E6880ac1cf2896",
 "NEARX":"0xb39EEB9E168eF6c639f5e282FEf1F6bC4Dcae375",
 "USDCN":"0x368EBb46ACa6b8D0787C96B2b20bD3CC3F2c45F7",
 "USDTN":"0x80Da25Da4D783E57d2FCdA0436873A193a4BEccF",
 "PULP":"0x04Ac48711BCdc45b4d223fb021E09DA73c71095e",
}

def sel(sig):
    h=keccak.new(digest_bits=256); h.update(sig.encode()); return "0x"+h.hexdigest()[:8]

S_BAL=sel("balanceOf(address)")
S_UND=sel("underlying()")

def batch_calls(calls):
    out=[]
    CH=20
    for i in range(0,len(calls),CH):
        chunk=calls[i:i+CH]
        payload=json.dumps([{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[{"to":t,"data":d},"latest"]} for j,(t,d) in enumerate(chunk)]).encode()
        req=urllib.request.Request(RPC,data=payload,headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        res=json.load(urllib.request.urlopen(req,timeout=90))
        m={item["id"]:item for item in res}
        for j in range(len(chunk)):
            it=m.get(j,{})
            out.append(it.get("result") if "error" not in it else None)
        i+=CH
    return out

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")

# underlying per market
unders={}
for name,m in MARKETS.items():
    r=None
    try:
        r=urllib.request.urlopen(urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":m,"data":S_UND},"latest"]}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"}),timeout=30)
        j=json.load(r)
        if "result" in j: unders[name]="0x"+j["result"][-40:]
    except Exception: pass
print("underlying map:", json.dumps(unders,indent=0))

calls=[]; meta=[]
for mname,m in MARKETS.items():
    own=unders.get(mname)
    for tname,t in UND.items():
        if own and t.lower()==own.lower(): continue
        calls.append((t,S_BAL+enc_addr(m))); meta.append((mname,tname))
res=batch_calls(calls)
found=0
for (mname,tname),r in zip(meta,res):
    if r and int(r,16)>0:
        found+=1
        print(f"NONZERO: {mname} holds {tname} = {int(r,16)}")
if found==0: print("no stray non-underlying balances on any cToken (sweepToken = latent grief only)")

# dead-market membership among known addresses
addrset=set()
import glob, os
for f in glob.glob("/home/heisenberg/CA/aurigami/analysis/borrowers_*.json"):
    try:
        d=json.load(open(f))
        if isinstance(d,list):
            for x in d:
                if isinstance(x,str) and x.startswith("0x"): addrset.add(x.lower())
                elif isinstance(x,dict):
                    for k in ("borrower","address","account"):
                        if k in x and isinstance(x[k],str): addrset.add(x[k].lower())
    except Exception as e: pass
print("known addresses:", len(addrset))
# use accountAssets(account,index) getter on the unitroller to list each account's markets
S_AA=sel("accountAssets(address,uint256)")
S_N=sel("getAssetsIn(address)")
sanity=0; frozen=[]
for a in sorted(addrset):
    # getAssetsIn(address) returns address[]
    data=S_N+enc_addr(a)
    try:
        req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":UNIT,"data":data},"latest"]}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        j=json.load(urllib.request.urlopen(req,timeout=30))
        r=j.get("result")
        if not r or len(r)<130: continue
        w=[int(r[2:][i:i+64],16) for i in range(0,len(r[2:]),64)]
        off=w[0]//32; ln=w[off]
        arr=["0x"+format(x,'040x') for x in w[off+1:off+1+ln]]
        dead=[k for k,v in MARKETS.items() if k in ("auTRI","auPLY","auUSN") and v.lower() in [x.lower() for x in arr]]
        if dead and any(int(x,16)!=0 for x in arr):
            # check membership real quick via known list intersection
            frozen.append((a,dead))
    except Exception as e: pass
print("accounts with dead-market in assetsIn:", len(frozen))
for a,d in frozen[:20]: print("  ",a,d)
