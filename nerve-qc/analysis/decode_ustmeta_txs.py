#!/usr/bin/env python3
"""Decode historical txs that touched USTMETA (from Covalent list) via receipts+logs."""
import json, urllib.request, os

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

TOPICS = {}
def topic_sig(t):
    return TOPICS.get(t, t)

TXS = [
 "0xdb3ef842563a03049eb26ff7c1a15a1f8afd145ad6837cfe775639bdb0bc79c9",
 "0xbffa6698c058047fc75d8c66821fcbcdec414cba2d86abdd247728c80afae1e4",
 "0x90d8298bb82d39131eadef0ad80b68e27f8d49a348c30664e704f74b4550e299",
 "0xad0a9ee681c8bfaf1d4a71f3873ab8da8f302674c1f619989add8d5bab6af16a",
 "0xbc0555b68da4709b9184101342987d00735bfbc22de64bb299d2538579c1dd2b",
 "0x42ff378b2a4f0672e7672acc43da510156e4bd351e1a461a36c21a70ca3860db",
 "0xa8388440f7989b6249698f62d2d7c1cc03da2db8c9e8bb0228c04e5b0ee309f8",
 "0x66dbeb430aab9d843fd328e70b28526da6ef0afd4a02e7aa81d5c6a658f33a55",
 "0x7ed6c04042d39e8716f6527f1231bfa50a3001f4872b0f00de34db9cd9681762",
]

def main():
    for h in TXS:
        tx=rpc(RPC,"eth_getTransactionByHash",[h])
        rc=rpc(RPC,"eth_getTransactionReceipt",[h])
        logs=rc.get("logs",[])
        for l in logs:
            if l["address"].lower() in ("0x2dcce1586b1664f41c72206900e404ec3ca130e0","0xd0fbf0a224563d5ffc8a57e4fda6ae080ebcf3d3"):
                pass
        print("="*100)
        print(h[:20], "block", int(tx["blockNumber"],16), "from", tx["from"], "to", tx["to"], "status", rc.get("status"))
        print("  input:", tx["input"][:200])
        for l in logs:
            addrs = l["address"].lower()
            if addrs in ("0x2dcce1586b1664f41c72206900e404ec3ca130e0",):
                print("   LOG in pool:", l["topics"][0][:70], "n=",len(l["topics"]))
            elif addrs in ("0xe9e7cea3dedca5984780bafc599bd69add087d56","0x55d398326f99059ff775485246999027b3197955","0x23396cf899ca06c4472205fc903bdb4de249d6fc","0xf2511b5e4fb0e5e2d123004b672ba14850478c14"):
                t0=l["topics"][0]
                kind = "Transfer" if t0.startswith("0xddf252ad") else "Approval" if t0.startswith("0x8c5be1e5") else t0[:18]
                vals = [int(x,16) for x in l["data"][2:].replace(""," ").split()] if l["data"] and l["data"]!="0x" else []
                print(f"   {kind} on {l['address'][:12]} topics={[t[:12] for t in l['topics']]} data={vals}")
        print("  logs total:", len(logs))
        # decode log addresses present
        addset = sorted({l["address"].lower() for l in logs})
        if not logs: print("   (no logs)")

if __name__=="__main__":
    main()
