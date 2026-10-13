#!/usr/bin/env python3
"""Decode recent EXTRA7 / EXTRA5 activity."""
import json, urllib.request, os

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"

def rpc(m,p):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=60))
    if "error" in r: raise RuntimeError(str(r["error"])[:120])
    return r.get("result")

SIGS={
 "0x91695586":"swapUnderlying? or swap(...)" ,
}
# known selectors (compute via cast at runtime if available)
import subprocess
def sel(sig):
    r=subprocess.run(["cast","sig",sig],capture_output=True,text=True)
    return r.stdout.strip()
CAND={
 sel("swap(uint8,uint8,uint256,uint256,uint256)"):"swap",
 sel("swapUnderlying(uint8,uint8,uint256,uint256,uint256)"):"swapUnderlying",
 sel("addLiquidity(uint256[],uint256,uint256)"):"addLiquidity",
 sel("removeLiquidity(uint256,uint256[],uint256)"):"removeLiquidity",
 sel("removeLiquidityOneToken(uint256,uint8,uint256,uint256)"):"removeLiquidityOneToken",
 sel("removeLiquidityImbalance(uint256[],uint256,uint256)"):"removeLiquidityImbalance",
 sel("withdrawAdminFees()"):"withdrawAdminFees",
 sel("pause()"):"pause",
 sel("unpause()"):"unpause",
 sel("deposit(uint256,uint256)"):"farmDeposit",
 sel("withdraw(uint256,uint256)"):"farmWithdraw",
 sel("emergencyWithdraw(uint256)"):"farmEmergency",
}
for k,v in CAND.items(): print(k,v)

def decode_tx(h):
    tx=rpc("eth_getTransactionByHash",[h])
    rc=rpc("eth_getTransactionReceipt",[h])
    inp=tx.get("input") or ""
    s=inp[:10] if len(inp)>=10 else ""
    kind=CAND.get(s,f"unknown {s}")
    print("="*100)
    print(h[:22],"blk",int(tx["blockNumber"],16),"from",tx["from"],"to",tx["to"],"status",rc.get("status"),"|",kind)
    print("   input:",inp[:300])
    for l in rc.get("logs",[]):
        t0=l["topics"][0]
        if t0.startswith("0xddf252ad"):
            frm="0x"+l["topics"][1][26:]; to="0x"+l["topics"][2][26:]
            val=int(l["data"],16) if l["data"] and l["data"]!="0x" else 0
            print(f"   Transfer {l['address'][:12]} {frm[:12]}->{to[:12]} {val}")
        else:
            print(f"   LOG {l['address'][:12]} t0={t0[:20]} topics={len(l['topics'])}")

if __name__=="__main__":
    import sys
    for h in sys.argv[1:]:
        decode_tx(h)
