#!/usr/bin/env python3
"""Scan PulseX V1/V2 top pairs: stored reserves vs live balances (skim-able excess)."""
import json, time, urllib.request, sys, os

RPC = "https://pulsechain-rpc.publicnode.com"
OUT = os.path.dirname(os.path.abspath(__file__))
BLOCK = None

def rpc_batch(calls, retries=4):
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[c,"latest"]} for i,c in enumerate(calls)]
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.loads(r.read())
            out = [None]*len(calls)
            for item in res:
                out[item["id"]] = item.get("result")
            return out
        except Exception as e:
            time.sleep(1.5*(a+1))
    return [None]*len(calls)

def block_number():
    data = json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode()
    req = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return int(json.loads(r.read())["result"],16)

def graph(subgraph, query):
    data = json.dumps({"query":query}).encode()
    req = urllib.request.Request(f"https://graph.pulsechain.com/subgraphs/name/pulsechain/{subgraph}", data=data, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for a in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                j = json.loads(r.read())
            if "data" in j: return j["data"]
        except Exception as e:
            time.sleep(2)
    return None

def pad(addr):
    return "0x" + addr.lower().replace("0x","").rjust(64,"0")

def selector(sig):
    # minimal keccak via hashlib? use known selectors
    known = {
      "getReserves()":"0x0902f1ac",
      "token0()":"0x0dfe1681",
      "token1()":"0xd21220a7",
      "totalSupply()":"0x18160ddd",
      "balanceOf(address)":"0x70a08231",
    }
    return known[sig]

def get_pairs(subgraph):
    pairs = []
    skip = 0
    while len(pairs) < 1000:
        q = '{ pairs(first:1000, skip:%d, orderBy:reserveUSD, orderDirection:desc, where:{reserveUSD_gt:"1000"}) { id reserveUSD reserve0 reserve1 totalSupply token0{id symbol decimals} token1{id symbol decimals} } }' % skip
        d = graph(subgraph, q)
        if not d or not d.get("pairs"): break
        batch = d["pairs"]
        pairs.extend(batch)
        if len(batch) < 1000: break
        skip += 1000
    return pairs

def main():
    global BLOCK
    BLOCK = block_number()
    print("block", BLOCK, flush=True)
    allpairs = []
    for sg, label in [("pulsex","v1"), ("pulsexv2","v2")]:
        ps = get_pairs(sg)
        print(label, "pairs from subgraph:", len(ps), flush=True)
        for p in ps:
            p["factory"] = label
        allpairs.extend(ps)
    # dedupe
    seen=set(); pairs=[]
    for p in allpairs:
        if p["id"] in seen: continue
        seen.add(p["id"]); pairs.append(p)
    print("total pairs:", len(pairs), flush=True)

    results=[]
    chunk=25
    for i in range(0, len(pairs), chunk):
        group = pairs[i:i+chunk]
        calls=[]
        for p in group:
            a=p["id"]
            calls.append({"to":a,"data":selector("getReserves()")})
            calls.append({"to":a,"data":selector("token0()")})
            calls.append({"to":a,"data":selector("token1()")})
            calls.append({"to":a,"data":selector("totalSupply()")})
            # balances for token0/token1 resolved later; do a second pass using subgraph token ids
            calls.append({"to":p["token0"]["id"],"data":selector("balanceOf(address)")+pad(a)[2:]})
            calls.append({"to":p["token1"]["id"],"data":selector("balanceOf(address)")+pad(a)[2:]})
        res = rpc_batch(calls)
        for j,p in enumerate(group):
            base=j*6
            try:
                r = res[base]
                if not r or r=="0x": continue
                r0=int(r[2:66],16); r1=int(r[66:130],16)
                b0=int(res[base+4],16) if res[base+4] and res[base+4]!="0x" else None
                b1=int(res[base+5],16) if res[base+5] and res[base+5]!="0x" else None
                ts=int(res[base+3],16) if res[base+3] and res[base+3]!="0x" else None
                rec={"pair":p["id"],"factory":p["factory"],"token0":p["token0"],"token1":p["token1"],
                     "reserve0":r0,"reserve1":r1,"bal0":b0,"bal1":b1,"totalSupply":ts,
                     "subgraph_reserveUSD":p.get("reserveUSD")}
                if b0 is not None: rec["excess0"]=b0-r0
                if b1 is not None: rec["excess1"]=b1-r1
                results.append(rec)
            except Exception as e:
                pass
        if i % 250 == 0:
            print("progress", i, "/", len(pairs), flush=True)
        time.sleep(0.15)
    json.dump({"block":BLOCK,"pairs":results}, open(os.path.join(OUT,"excess_scan.json"),"w"), indent=1)
    # summary
    both_pos = [r for r in results if r.get("excess0") is not None and r.get("excess1") is not None and r["excess0"]>0 and r["excess1"]>=0]
    any_exc = [r for r in results if (r.get("excess0") or 0)>0 or (r.get("excess1") or 0)>0]
    neg = [r for r in results if (r.get("excess0") or 0)<0 or (r.get("excess1") or 0)<0]
    print("scanned:",len(results),"any excess:",len(any_exc),"skim-able(both>=0, one>0):",len(both_pos),"negative(FOT-ish):",len(neg))
    for r in sorted(any_exc, key=lambda x: max(x.get("excess0") or 0, x.get("excess1") or 0), reverse=True)[:25]:
        print(f"{r['pair']} {r['factory']} ex0={r.get('excess0')} ex1={r.get('excess1')} res0={r['reserve0']} res1={r['reserve1']} sub=${r.get('subgraph_reserveUSD')}")

if __name__=="__main__":
    main()
