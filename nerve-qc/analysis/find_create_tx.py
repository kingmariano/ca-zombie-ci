#!/usr/bin/env python3
"""Find the top-level tx that created a clone internally: scan block receipts."""
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

def main(block, want):
    blk=rpc(RPC,"eth_getBlockByNumber",[hex(block),True])
    txs=blk.get("transactions",[])
    print(f"block {block}: {len(txs)} txs, want contract {want}")
    hits=[]
    def chk(tx):
        try:
            rc=rpc(RPC,"eth_getTransactionReceipt",[tx["hash"]])
            if rc and rc.get("contractAddress") and rc["contractAddress"].lower()==want.lower():
                return (tx["hash"], tx["from"], tx.get("to"), int(tx.get("gasUsed") or '0x0',16))
        except Exception as e:
            return None
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        for res in ex.map(chk, txs):
            if res: hits.append(res); print("FOUND:",res)
    if not hits:
        # maybe created earlier than binary search said for a different reason; check balance-less
        print("no direct contractAddress match; showing txs to contract-ish targets")
        for tx in txs[:60]:
            to=tx.get("to")
            if to and to.lower()!=want.lower():
                c=rpc(RPC,"eth_getCode",[to,"latest"])
                if c and len(c)>2:
                    print("  tx",tx["hash"][:20],"from",tx["from"],"to",to,"codelen",len(c)//2-1,"input",(tx.get("input") or "")[:40])

if __name__=="__main__":
    main(int(sys.argv[1]), sys.argv[2])
