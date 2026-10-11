#!/usr/bin/env python3
"""Completeness sweep: balances of all contracts deployed by the Ra deployer EOA (from
analysis/deployer_txs.json) across the main Fraxtal tokens + native. Read-only."""
import json, urllib.request, time

RPC = "https://rpc.frax.com"
TOKENS = {
    "frxUSD": "0xfc00000000000000000000000000000000000001",
    "WFRAX": "0xfc00000000000000000000000000000000000002",
    "FPIS": "0xfc00000000000000000000000000000000000004",
    "sfrxETH": "0xfc00000000000000000000000000000000000005",
    "frxETH": "0xfc00000000000000000000000000000000000006",
    "sfrxUSD": "0xfc00000000000000000000000000000000000008",
    "axlUSDC": "0xeb466342c4d449bc9f53a865d5cb90586f405215",
    "WBTC": "0x7f3a9afc827aeedb0c5dc1a66c0baa41cd7289f0",
    "frxETH2": "0xecc68d0451e20292406967fe7c04280e5238ac7d",
}

class Rpc:
    def __init__(self, url): self.url=url; self.id=0
    def batch(self, calls):
        payload=[]
        for (to,data) in calls:
            self.id+=1
            payload.append({"jsonrpc":"2.0","id":self.id,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
        req=urllib.request.Request(self.url,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
        for _ in range(4):
            try:
                with urllib.request.urlopen(req,timeout=60) as r: resp=json.loads(r.read())
                byid={x["id"]:x.get("result") for x in resp if isinstance(x,dict)}
                return [byid.get(i) for i in range(self.id-len(calls)+1,self.id+1)]
            except Exception: time.sleep(1.5)
        raise RuntimeError("fail")

def enc(a): return a.lower().replace("0x","").rjust(64,"0")
def du(h): return 0 if h in (None,"0x") else int(h,16)

def main():
    d=json.load(open("/home/heisenberg/CA/ra-exchange/analysis/deployer_txs.json"))
    addrs=[]
    for x in d["result"]:
        ca=x.get("contractAddress")
        if ca: addrs.append(ca)
    print("deployed contracts:", len(addrs))
    rpc=Rpc(RPC)
    out={}
    for a in addrs:
        calls=[(t,"0x70a08231"+enc(a)) for t in TOKENS.values()]
        calls.append((a,"0x18160ddd"))  # totalSupply (for LP/proxies it may revert)
        res=rpc.batch(calls)
        bals={k:du(res[i]) for i,k in enumerate(TOKENS)}
        nz={k:v for k,v in bals.items() if v>0}
        # native balance
        payload={"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":[a,"latest"]}
        req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
        with urllib.request.urlopen(req,timeout=30) as r: nat=int(json.loads(r.read())["result"],16)
        out[a]={"tokens":nz,"native":nat}
        if nz or nat>10**15:
            print(a, "native=%.4f"%(nat/1e18), {k:str(v) for k,v in nz.items()})
    json.dump(out,open("/home/heisenberg/CA/ra-exchange/analysis/deployer_contract_balances.json","w"),indent=1)
    print("done")

if __name__=="__main__":
    main()
