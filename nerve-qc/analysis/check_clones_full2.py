#!/usr/bin/env python3
"""Extended clone check on the FULL address set: any 45-byte EIP-1167 clone,
plus contracts referencing the three Nerve MetaSwap impls."""
import json, urllib.request, os, time, sys, concurrent.futures

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"
IMPLS=["f642f2a626a8b732619606c493abfc2433dd2d35",
       "fa97adb530b38639a83b1890ee17942804035ddf",
       "fcc3976ebdc240ce83e8a94bc83be5cd4ad4a053"]

def rpc(m,p,tries=5):
    for i in range(tries):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            return json.load(urllib.request.urlopen(req,timeout=45))
        except Exception as e:
            if i==tries-1: return {"error":{"message":str(e)[:80]}}
            time.sleep(1+2*i)

def main():
    addrs=json.load(open("/home/heisenberg/CA/nerve-qc/analysis/all_addrs.json"))
    print("checking",len(addrs))
    clones={}; refs=set(); contracts=0; done=0
    def work(a):
        r=rpc("eth_getCode",[a,"latest"])
        return a, r.get("result") if "result" in r else None
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        for a,c in ex.map(work,addrs):
            done+=1
            if done%1500==0: print(f"  {done}/{len(addrs)}",file=sys.stderr)
            if not c or c=="0x": continue
            contracts+=1
            cl=c.lower()
            if len(c)==90 and cl.startswith("0x363d3d373d3d3d363d73"):
                clones[a]="0x"+cl[2+20:2+60]
            for imp in IMPLS:
                if imp in cl:
                    refs.add(a)
    print("contracts:",contracts,"clones:",len(clones),"refs:",len(refs))
    print("-- clones --")
    for a,i in sorted(clones.items(),key=lambda x:x[1]): print(f"  {a} -> {i}")
    print("-- contracts containing impl refs (not 45-byte clones) --")
    for a in sorted(refs):
        if a not in clones: print(f"  {a}")
    with open("/home/heisenberg/CA/nerve-qc/analysis/clones_full2.json","w") as f:
        json.dump({"clones":clones,"refs":sorted(refs)},f,indent=2)

if __name__=="__main__": main()
