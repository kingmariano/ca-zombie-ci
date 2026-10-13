#!/usr/bin/env python3
"""Find creation block + tx + deployer of a contract via binary search on eth_getCode."""
import json, urllib.request, os, sys

def pick():
    k=os.environ.get("ANKR_API_KEY")
    cands=[f"https://rpc.ankr.com/bsc/{k}"] if k else []
    cands.append("https://bsc-rpc.publicnode.com")
    for u in cands:
        try:
            if rpc(u,"eth_blockNumber",[]): return u
        except Exception: pass
    raise SystemExit("no rpc")

def rpc(u,m,p):
    req=urllib.request.Request(u,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=45))
    if "error" in r: raise RuntimeError(str(r["error"])[:80])
    return r.get("result")

RPC=pick()

def code_at(a,b):
    h=hex(b)
    r=rpc(RPC,"eth_getCode",[a,h])
    return r and r!="0x"

def find_creation(addr, lo=1, hi=None):
    if hi is None: hi=int(rpc(RPC,"eth_blockNumber",[]),16)
    if not code_at(addr,hi): return None
    if code_at(addr,lo): return lo
    while lo<hi-1:
        mid=(lo+hi)//2
        if code_at(addr,mid): hi=mid
        else: lo=mid
    return hi

def block_txs(b):
    return rpc(RPC,"eth_getBlockByNumber",[hex(b),True]) or {}

def main():
    targets = sys.argv[1:] or ["0x2dcCe1586b1664f41C72206900e404Ec3cA130e0"]
    out={}
    for a in targets:
        b=find_creation(a)
        print(f"{a} creation block={b}")
        if b is None: continue
        blk=block_txs(b)
        for tx in blk.get("transactions",[]):
            inp=(tx.get("input") or "").lower()
            if tx.get("to") in (None,"0x0000000000000000000000000000000000000000") and inp:
                # EIP-1167 initcode contains impl address in the middle
                out[a]={"block":b,"tx":tx["hash"],"from":tx["from"],"input_len":len(inp)}
                print("  deploy tx:",tx["hash"],"from",tx["from"])
                break
        else:
            print("  no creation tx found in block (maybe internal)")
    with open("/home/heisenberg/CA/nerve-qc/analysis/creators.json","w") as f:
        json.dump(out,f,indent=2)

if __name__=="__main__":
    main()
