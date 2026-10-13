#!/usr/bin/env python3
"""Check every LP-transfer counterparty for EIP-1167 clone code (Nerve impls, any impl)."""
import json, urllib.request, os, time, sys, concurrent.futures

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"

def rpc(m,p,tries=4):
    for i in range(tries):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            return json.load(urllib.request.urlopen(req,timeout=45))
        except Exception as e:
            if i==tries-1: return {"error":{"message":str(e)[:80]}}
            time.sleep(1+1.5*i)

def getcode(a):
    r=rpc("eth_getCode",[a,"latest"])
    return r.get("result") if "result" in r else None

def main():
    addrs=json.load(open("/home/heisenberg/CA/nerve-qc/analysis/lp_transfer_addrs.json"))
    uniq=sorted({a.lower() for v in addrs.values() for a in v})
    print("addresses to check:",len(uniq))
    base_lp={"0xf2511b5e4fb0e5e2d123004b672ba14850478c14","0xd1d5af92c606c6f2ec59d453f57a6fcc188d7db5","0x0d283bf16a9bde49cfc48d8dc050af28b71bdd90"}
    clones={}
    contracts=0
    done=0
    def work(a):
        c=getcode(a)
        return a,c
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        for a,c in ex.map(work,uniq):
            done+=1
            if done%1000==0: print(f"  checked {done}/{len(uniq)}", file=sys.stderr)
            if not c or c=="0x": continue
            contracts+=1
            if len(c)==90 and c.startswith("0x363d3d373d3d3d363d73"):
                impl="0x"+c[2+20:2+60]
                clones[a]=impl
            elif "f642f2a626a8b732619606c493abfc2433dd2d35" in c.lower():
                clones[a]="contains-impl-ref"
    print("contracts:",contracts)
    print("clones found:",len(clones))
    for a,i in sorted(clones.items(),key=lambda x:x[1]):
        print(f"  {a} -> {i}")
    # sanity: known clones present?
    known=["0x2dcce1586b1664f41c72206900e404ec3ca130e0","0xd0fbf0a224563d5ffc8a57e4fda6ae080ebcf3d3","0x96b849a73db2cc769b4abe770aab141aac9014d6",
           "0x97b9054122ef8888590934f0ec8e10580232e85d","0xc80cc653392f4734201331e39a66aa8a483d29bd","0xca9d9c7800b7d1d3a1988a7d93927424a1bbea7f",
           "0xb1669a60a7db67aa84e5faf2ae3123aa99237459","0xf100326c19996eaf2d8e93a503725f643e36099c","0x0144e7d25644c7ca6038f4afbfcd3b1a119ab3ce",
           "0xbc7477e46a95758de5012744f7a350a4e0d03484","0x0eafaa7ed9866c1f08ac21dd0ef3395e910f7114"]
    print("known present:",[k for k in known if k in clones])
    with open("/home/heisenberg/CA/nerve-qc/analysis/clones_full.json","w") as f:
        json.dump(clones,f,indent=2)

if __name__=="__main__":
    main()
