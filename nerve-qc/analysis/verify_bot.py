#!/usr/bin/env python3
"""Verify bot swaps at exact blocks; identify bot + rUSD."""
import json, urllib.request, os, subprocess

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"

def rpc(m,p):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=60))
    if "error" in r: raise RuntimeError(str(r["error"])[:140])
    return r.get("result")

def sig(s): return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()[2:]
def u8(x): return hex(x)[2:].rjust(64,"0")
def u256(x): return hex(int(x))[2:].rjust(64,"0")
def call(to,data,blk):
    r=rpc("eth_call",[{"to":to,"data":data},hex(blk) if isinstance(blk,int) else blk])
    return int(r,16) if r and r!="0x" else None

CS=sig("calculateSwap(uint8,uint8,uint256)")
GV=sig("getVirtualPrice()")
GIB=sig("getTokenBalance(uint8)")
GETA=sig("getAdminBalance(uint256)")
TS=sig("totalSupply()")
BAL=sig("balanceOf(address)")
def padaddr(a): return a.lower().replace("0x","").rjust(64,"0")

P="0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114"
LP3="0xf2511b5e4fb0e5e2d123004b672ba14850478c14"
RUSD="0x07663837218a003e66310a01596bf4b0"  # placeholder fixed below
RUSD="0x07663837218a003e66310a01596af4bf4e44623d"
BOT="0xd42fce65b9ce5ded9d3a4ecaa20955bab52daa19"
P3="0x1B3771a66ee31180906972580adE9b81AFc5fCDc"

def snap(blk,label):
    print(f"-- {label} block {blk}")
    print("   pool vp(3pool):", call(P3,"0x"+GV,blk)/1e18)
    print("   meta vp:", call(P,"0x"+GV,blk)/1e18,
          "int0:",call(P,"0x"+GIB+u256(0),blk),"int1:",call(P,"0x"+GIB+u256(1),blk),
          "adm0:",call(P,"0x"+GETA+u256(0),blk),"adm1:",call(P,"0x"+GETA+u256(1),blk))
    print("   bot LP3:",call(LP3,"0x"+BAL+padaddr(BOT),blk),"bot rUSD:",call(RUSD,"0x"+BAL+padaddr(BOT),blk))
    print("   pool LP3:",call(LP3,"0x"+BAL+padaddr(P),blk),"pool rUSD:",call(RUSD,"0x"+BAL+padaddr(P),blk))

def main():
    B1=123863610  # before tx1
    B2=123863617  # before tx2
    B3=123863619  # after tx2
    snap(B1,"before swap1")
    snap(B2,"before swap2")
    snap(B3,"after swap2")
    # view math at B1 for the bot's swap1 inputs
    dx1=108818453578260441
    y1=call(P,"0x"+CS+u8(1)+u8(0)+u256(dx1),B1)
    print("calc swap1(1->0,dx=0.108818...) at B1:",y1, "actual out was 2433648062703415355")
    y2=call(P,"0x"+CS+u8(0)+u8(1)+u256(2432163331903147509),B2)
    print("calc swap2(0->1,dx=2.432163...) at B2:",y2, "actual out was",dx1)
    # and what the bot actually should have gotten by fair round trip
    y1b=call(P,"0x"+CS+u8(1)+u8(0)+u256(dx1),B1)
    back=call(P,"0x"+CS+u8(0)+u8(1)+u256(y1b),B1)
    print("same-block fair round trip at B1: back:",back,"diff:",back-dx1)

if __name__=="__main__": main()
