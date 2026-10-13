#!/usr/bin/env python3
"""Round-trip math on live metapool state: does swap(i,j) then swap(j,i) leak?"""
import json, urllib.request, os

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"

def rpc(m,p):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=45))
    if "error" in r: raise RuntimeError(str(r["error"])[:120])
    return r.get("result")

def u8(x): return hex(x)[2:].rjust(64,"0")
def u256(x): return hex(int(x))[2:].rjust(64,"0")
def call(to,data,blk="latest"):
    r=rpc("eth_call",[{"to":to,"data":data},blk])
    return int(r,16) if r and r!="0x" else None

CALC_SWAP="0xa95b089f"   # calculateSwap(uint8,uint8,uint256)
CALC_SWAPU="0xa11e7689"  # calculateSwapUnderlying(uint8,uint8,uint256)? verify
# verify selectors with cast later; for now compute via cast output mapping
import subprocess
def sig(s):
    return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()
CS=sig("calculateSwap(uint8,uint8,uint256)")[2:]
CSU=sig("calculateSwapUnderlying(uint8,uint8,uint256)")[2:]
GIB=sig("getTokenBalance(uint8)")[2:]
GETA=sig("getAdminBalance(uint256)")[2:]
GT=sig("getToken(uint8)")[2:]
PA=sig("paused()")[2:]
GV=sig("getVirtualPrice()")[2:]
print("calculateSwap sel:",CS,"calculateSwapUnderlying:",CSU)

POOLS={
 "EXTRA7":"0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114",
 "EXTRA6":"0xbC7477e46A95758dE5012744f7A350A4E0d03484",
 "EXTRA5":"0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE",
 "EXTRA0":"0x97B9054122eF8888590934F0eC8E10580232E85d",
 "EXTRA1":"0xC80Cc653392f4734201331E39a66aA8a483D29BD",
 "EXTRA2":"0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f",
 "EXTRA3":"0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459",
 "EXTRA4":"0xF100326c19996eaf2d8E93A503725F643e36099C",
 "FUSDTMETA":"0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3",
 "USTMETA":"0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
}

def cs(pool,i,j,dx,blk="latest"):
    return call(pool,"0x"+CS+u8(i)+u8(j)+u256(dx),blk)

def main():
    for name,p in POOLS.items():
        try:
            t0=call(p,"0x"+GT+u256(0)); t1=call(p,"0x"+GT+u256(1))
            i0=call(p,"0x"+GIB+u256(0)); i1=call(p,"0x"+GIB+u256(1))
            a0=call(p,"0x"+GETA+u256(0)); a1=call(p,"0x"+GETA+u256(1))
            vp=call(p,"0x"+GV)
            paused=call(p,"0x"+PA)
            print(f"== {name} paused={paused} vp={vp/1e18:.9f}")
            print(f"   internal0={i0} internal1={i1} admin0={a0} admin1={a1}")
            # round trip test: sell dx of i, get y of j, sell y back
            for i,j,label in [(0,1,"t0->t1->t0"),(1,0,"t1->t0->t1")]:
                for dx in [10**15, 10**16, 10**17, i0//10 if i==0 else i1//10, i0//4 if i==0 else i1//4]:
                    if not dx or dx<=0: continue
                    try:
                        y=cs(p,i,j,dx)
                        if y is None: continue
                        back=cs(p,j,i,y)
                        if back is None: continue
                        print(f"   {label} dx={dx} -> mid={y} -> back={back} diff={back-dx:+d} ({'PROFIT' if back>dx else 'loss'})")
                    except Exception as e:
                        print(f"   {label} dx={dx} ERR {str(e)[:60]}")
                    break  # one size per direction for now
        except Exception as e:
            print(f"== {name} ERROR {str(e)[:80]}")

if __name__=="__main__": main()
