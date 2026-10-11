#!/usr/bin/env python3
"""Full state read for metapool 0xd0fbf0a2 (+ compare with 0x2dcCe158)."""
import json, urllib.request
RPC="https://bsc-rpc.publicnode.com"
def pad(x): return x.lower().replace("0x","").rjust(64,"0")
def rpc_batch(calls, url=RPC):
    payload=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"r/1.0"})
    with urllib.request.urlopen(req,timeout=90) as r: out=json.load(r)
    out.sort(key=lambda x:x["id"]); return [o.get("result") for o in out]

SEL={"owner":"0x8da5cb5b","paused":"0x5c975abb","vprice":"0xe25aa5fa","A":"0xd46300fd","Ap":"0x0ba81959","swapStorage":"0x5fd65f0f","metaSwapStorage":"0x2d74d4e9","totalSupply":"0x18160ddd"}
META="0xd0fbf0a224563d5ffc8a57e4fda6ae080ebcf3d3"
def main():
    bh=rpc_batch([("eth_blockNumber",[])])[0]; block=int(bh,16)
    calls,meta=[],[]
    for k,s in SEL.items():
        calls.append(("eth_call",[{"to":META,"data":s},bh])); meta.append((k,))
    for i in range(4):
        calls.append(("eth_call",[{"to":META,"data":"0x82b86600"+pad(hex(i))},bh])); meta.append((f"getToken({i})",))
        calls.append(("eth_call",[{"to":META,"data":"0x91ceb3eb"+pad(hex(i))},bh])); meta.append((f"getTokenBalance({i})",))
        calls.append(("eth_call",[{"to":META,"data":"0xef0a712f"+pad(hex(i))},bh])); meta.append((f"getAdminBalance({i})",))
    res=rpc_batch(calls)
    out={k[0]:v for k,v in zip(meta,res)}
    print("block",block)
    print(json.dumps(out,indent=1))
    with open("/home/heisenberg/CA/nerve/analysis/metapool_fusdt_state.json","w") as f:
        json.dump({"block":block,"data":out},f,indent=2)
if __name__=="__main__": main()
