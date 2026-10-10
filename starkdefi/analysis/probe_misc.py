#!/usr/bin/env python3
"""Probe: _6bdf53 on fixed classes, pair self-LP balances, handler/to identities, router class."""
import json, urllib.request, subprocess, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")

def rpc(method, params, timeout=45, retries=5):
    last=None
    for i in range(retries):
        url=ENDPOINTS[i%len(ENDPOINTS)]
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: out=json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last=out
        except Exception as e: last=repr(e)
        time.sleep(0.3)
    raise RuntimeError(str(last)[:140])
def sel(f):
    h=subprocess.run(["cast","keccak",f],capture_output=True,text=True).stdout.strip()
    return hex(int(h,16)&((1<<250)-1))
def call(a,s,cd,block): return rpc("starknet_call",[{"contract_address":a,"entry_point_selector":s,"calldata":cd},{"block_number":block}])
def u256(r,i=0): return int(r[i],16)+(int(r[i+1],16)<<128)

def main():
    block=rpc("starknet_blockNumber",[])
    print("block",block,flush=True)
    meta=json.load(open(os.path.join(OUT,"factory_state.json")))
    chs=meta["pair_class_hashes"]
    pairs={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pairs_raw.jsonl"))}
    S6=sel("_6bdf53")
    print("_6bdf53 selector:",S6)
    # probe _6bdf53 on a 0x4a56 pair and a 0x30ca pair
    tested={}
    for p,ch in chs.items():
        if ch[:12] not in tested:
            tested[ch[:12]]=p
    for ch,p in tested.items():
        for arg in ["0x0","0x1"]:
            try:
                r=call(p,S6,[arg],block)
                print(f"  _6bdf53({arg}) on {ch} -> OK {r}")
            except Exception as e:
                print(f"  _6bdf53({arg}) on {ch} -> REVERT {str(e)[:110]}")
    # pair self LP balances
    S_BAL=sel("balanceOf")
    def selfbal(p): 
        try: return p, u256(call(p,S_BAL,[p],block))
        except Exception as e: return p, f"ERR"
    res=[]
    with ThreadPoolExecutor(max_workers=8) as ex:
        for f in as_completed([ex.submit(selfbal,p) for p in pairs]):
            res.append(f.result())
    nz=[(p,v) for p,v in res if isinstance(v,int) and v>0]
    print("pairs with self LP balance:",len(nz))
    for p,v in nz[:10]: print("  ",p[:18],v, "class",chs[p][:12])
    # handler/to/router identities
    F="0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e"
    for name,addr in [("fee_handler","0x283b6df5330e5ba0c9ffc4a5c80de4227bdab78b6a155654ae78f220d6bdf53"),
                      ("fee_to","0x1335ab829016118d33c11475eee49f302fd48a2d207aa74067cda44b0942279")]:
        ch=rpc("starknet_getClassHashAt",[{"block_number":block},addr])
        nonce=None
        try: nonce=rpc("starknet_getNonce",[{"block_number":block},addr])
        except Exception: pass
        print(name,addr,"class:",ch[:24] if isinstance(ch,str) else ch, "nonce:",nonce)
    # router: find deployed router via factory? try known selectors on candidate addresses
    # StarkDeFi router address may be discoverable via pair 'factory' only. Try Voyager-less: check a few known deployment addresses from repo docs
    import glob
    readme=open("/tmp/opencode/starkdefi-repo/README.md").read() if os.path.exists("/tmp/opencode/starkdefi-repo/README.md") else ""
    import re
    addrs=re.findall(r"0x[0-9a-fA-F]{60,64}", readme)
    print("addresses in README:",addrs[:10])

if __name__=="__main__":
    main()
