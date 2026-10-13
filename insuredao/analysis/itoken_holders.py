#!/usr/bin/env python3
"""iToken holders via Transfer logs (read-only). RPC from env, never persisted."""
import json, os, sys, urllib.request, subprocess

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
RPC=os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
MARKETS = sys.argv[1:] or [
 "0x22453153978D0C25f86010c0fd405527feD9764b",
 "0x86c82E8cD8A865f01A8CeBed870Af5d58e69a439",
 "0x1CF1195aFB01DD115647E4989e63AfE6DdD65030",
 "0x8c4943100bEc96e3381a544Da82B91713a4BC062",
 "0xDFdFcFEdb96e0979825C6B463cb8a971fE367d5D",
 "0xDAea5b1B6b12Ac4c4f51aB12649e96ab3aB98C3A",
 "0xd5f1Ab3c61eF3a6a6f1AA6141256Aa008D2fb5A1",
 "0x7E08daB409Ad1bCeBc5bE5674CB2C0f3540A4d3d",
]
TRANSFER=subprocess.check_output(["cast","keccak","Transfer(address,address,uint256)"]).decode().strip()

def rpc(method, params, url=None):
    u=url or RPC
    req=urllib.request.Request(u,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":UA})
    r=json.load(urllib.request.urlopen(req,timeout=120))
    if "error" in r: raise RuntimeError(r["error"])
    return r.get("result")

def get_logs(addr, from_b, to_b, url=None):
    return rpc("eth_getLogs",[{"address":addr,"topics":[TRANSFER],"fromBlock":hex(from_b),"toBlock":hex(to_b)}],url)

def balance(addr, who):
    d="0x70a08231"+who[2:].rjust(64,"0")
    return int(rpc("eth_call",[{"to":addr,"data":d},"latest"]),16)

def main():
    latest=int(rpc("eth_blockNumber",[]),16)
    out={}
    for m in MARKETS:
        addrs=set()
        logs=[]
        try:
            logs=get_logs(m,14252966,latest)
        except Exception as e:
            # chunk fallback
            try:
                for start in range(14252966,latest,500000):
                    end=min(start+499999,latest)
                    try:
                        logs+=get_logs(m,start,end)
                    except Exception:
                        pass
            except Exception as e2:
                out[m]={"error":repr(e)}
                continue
        for lg in logs:
            t=lg["topics"]
            if len(t)==3:
                addrs.add("0x"+t[1][-40:]); addrs.add("0x"+t[2][-40:])
            elif len(t)==4:  # ERC721 style (not expected)
                addrs.add("0x"+t[1][-40:]); addrs.add("0x"+t[2][-40:])
        bals={}
        for a in addrs:
            try:
                b=balance(m,a)
                if b: bals[a]=b
            except Exception: pass
        out[m]={"transfers":len(logs),"holders":len(bals),
                "top":sorted(bals.items(),key=lambda x:-x[1])[:12]}
        print(f"{m}: transfers={len(logs)} holders={len(bals)} top={sorted(bals.items(),key=lambda x:-x[1])[:8]}",flush=True)
    json.dump(out,open("analysis/itoken-holders.json","w"),indent=1)

if __name__=="__main__":
    main()
