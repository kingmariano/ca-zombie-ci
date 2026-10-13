#!/usr/bin/env python3
"""Fingerprint the 3 new candidate contracts + verify BTC/ETH LP token addresses."""
import json, urllib.request, os, hashlib

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"

def rpc(m,p):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=45))
    if "error" in r: raise RuntimeError(str(r["error"])[:120])
    return r.get("result")

def u256(x): return hex(int(x))[2:].rjust(64,"0")
def padaddr(a): return a.lower().replace("0x","").rjust(64,"0")
def readaddr(w):
    if not isinstance(w,str) or len(w)<66: return None
    a="0x"+w[2:][24:64]
    return None if int(a,16)==0 else a

NEW=["0x877a8437e76443cfcacd05d21c3793070637d82f",
     "0xcb922e4a5370020acf2d0e29754e0a995dec5b27",
     "0xf873ec132f38efb86bd071234b4316878b48fa97"]

SEL={"owner()":"0x8da5cb5b","paused()":"0x5c975abb","admin()":"0xf851a440","getVirtualPrice()":"0xe25aa5fa",
     "metaSwapStorage()":"0x2d74d4e9","totalSupply()":"0x18160ddd","swapStorage()":"0x5fd65f0f"}

def probe(a,label):
    c=rpc("eth_getCode",[a,"latest"])
    print(f"== {label} {a} code_len={len(c)//2-1}")
    print("   code head:",c[:120])
    if "f642f2a6" in c.lower():
        i=c.lower().find("f642f2a6")
        print("   impl ref at code offset",i, "=>", "0x"+c[i:i+40])
    for k,s in SEL.items():
        try:
            r=rpc("eth_call",[{"to":a,"data":s},"latest"])
            print(f"   {k} -> {r if not r or len(r)<=66 else r[:130]}")
        except Exception as e:
            print(f"   {k} ERR {str(e)[:60]}")
    # token scan
    for i in range(4):
        try:
            t=readaddr(rpc("eth_call",[{"to":a,"data":"0x82b86600"+u256(i)},"latest"]))
            if t:
                internal=rpc("eth_call",[{"to":a,"data":"0x91ceb3eb"+u256(i)},"latest"])
                admin=rpc("eth_call",[{"to":a,"data":"0xef0a712f"+u256(i)},"latest"])
                bal=rpc("eth_call",[{"to":t,"data":"0x70a08231"+padaddr(a)},"latest"])
                sym=rpc("eth_call",[{"to":t,"data":"0x95d89b41"},"latest"])[:100]
                print(f"   [{i}] token={t} internal={int(internal,16) if internal and internal!='0x' else internal} admin={int(admin,16) if admin and admin!='0x' else admin} bal={int(bal,16) if bal and bal!='0x' else bal} symbytes={sym}")
        except Exception as e:
            print(f"   [{i}] ERR {str(e)[:60]}")
            break

def main():
    for a in NEW: probe(a,a[:10])
    print("\n== base pool lpToken check ==")
    for name,pool in [("BTC","0x6C341938bB75dDe823FAAfe7f446925c66E6270c"),("ETH","0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0"),("P3","0x1B3771a66ee31180906972580adE9b81AFc5fCDc")]:
        st=rpc("eth_call",[{"to":pool,"data":SEL["swapStorage()"]},"latest"])
        # struct: (uint256 A, uint256 fee, uint256 adminFee, uint256 withdrawFee, uint256 defaultDepositFee, uint256 defaultWithdrawFee, address devaddr, address lpToken) -- actual field order per source
        words=[st[2:][i:i+64] for i in range(0,len(st[2:]),64)]
        print(name,"swapStorage words:",len(words))
        print("   raw:",st)
    # check the supposed LP tokens
    for nm,addr in [("btcLP?","0xd1d5af92c606c6f2ec59d453f57a6fcc188d7db5"),("ethLP?","0x0d283bf16a9bde49cfc48d8dc050af28b71bdd90")]:
        c=rpc("eth_getCode",[addr,"latest"])
        ts=rpc("eth_call",[{"to":addr,"data":"0x18160ddd"},"latest"])
        own=rpc("eth_call",[{"to":addr,"data":"0x8da5cb5b"},"latest"])
        print(nm,addr,"codelen",len(c)//2-1,"totalSupply",int(ts,16) if ts and ts!='0x' else ts,"owner",readaddr(own))

if __name__=="__main__": main()
