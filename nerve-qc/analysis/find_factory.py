#!/usr/bin/env python3
"""Scan unique tx targets in a creation block for the clone-factory pattern."""
import json, urllib.request, os, sys, concurrent.futures

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
    if "error" in r: raise RuntimeError(str(r["error"])[:100])
    return r.get("result")

RPC=pick()

def main(block, needle_hex):
    blk=rpc(RPC,"eth_getBlockByNumber",[hex(block),True])
    txs=blk.get("transactions",[])
    uniq=sorted({tx["to"].lower() for tx in txs if tx.get("to")})
    print(f"block {block}: {len(txs)} txs, {len(uniq)} unique targets")
    hits=[]
    def chk(a):
        try:
            c=rpc(RPC,"eth_getCode",[a,"latest"])
            if c and needle_hex in c.lower():
                return (a, len(c)//2-1)
        except Exception as e:
            return None
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        for res in ex.map(chk, uniq):
            if res:
                hits.append(res); print("MATCH:", res)
    # also check sender addresses (factories can be called indirectly)
    uniq_from=sorted({tx["from"].lower() for tx in txs if tx.get("from")})
    def chk2(a):
        try:
            c=rpc(RPC,"eth_getCode",[a,"latest"])
            if c and needle_hex in c.lower():
                return (a, len(c)//2-1)
        except Exception:
            return None
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        for res in ex.map(chk2, uniq_from):
            if res:
                hits.append(res); print("MATCH(from):", res)
    print("total hits:", len(hits))
    with open("/home/heisenberg/CA/nerve-qc/analysis/factory_candidates.json","w") as f:
        json.dump({"block":block,"needle":needle_hex,"hits":hits},f,indent=2)

if __name__=="__main__":
    main(int(sys.argv[1]), sys.argv[2])
