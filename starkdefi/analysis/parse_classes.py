#!/usr/bin/env python3
"""Parse deployed class ABIs fully (interfaces) and diff versions."""
import json, urllib.request, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "analysis")

def rpc(method, params, timeout=60, retries=4):
    last=None
    for i in range(retries):
        url=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"][i%3]
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: out=json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last=out
        except Exception as e: last=repr(e)
    raise RuntimeError(f"{method}: {last}")

def abi_functions(abi):
    funcs={}
    def walk(items, iface=None):
        for it in items:
            t=it.get("type")
            if t=="function":
                sig=(iface or "")+"::"+it["name"]+"("+",".join(i["type"] for i in it.get("inputs",[]))+")"
                funcs[sig]=it.get("state_mutability","?")
            elif t=="interface":
                walk(it.get("items",[]), it.get("name"))
            elif t=="impl":
                walk(it.get("items",[]), it.get("name"))
            elif t=="constructor":
                funcs["constructor("+",".join(i["type"] for i in it.get("inputs",[]))+")"]="constructor"
    walk(abi)
    return funcs

def main():
    classes=json.load(open(os.path.join(OUT,"class_abis.json")))
    full={}
    for name, rec in classes.items():
        ch=rec["class_hash"]
        cls=rpc("starknet_getClass",["latest",ch])
        abi=cls.get("abi")
        if isinstance(abi,str): abi=json.loads(abi)
        fns=abi_functions(abi)
        eps=cls.get("entry_points_by_type",{})
        sel2name={}
        # map selectors to names via starknet_keccak? names->selector not in RPC; store raw
        full[name]={"class_hash":ch,"functions":fns,
                    "external_selectors":[e["selector"] for e in eps.get("EXTERNAL",[])]}
        print(name, ch[:16], "abi_funcs:",len(fns), "ext_sel:",len(eps.get("EXTERNAL",[])))
    # diff pairs
    def diff(a,b):
        fa=set(full[a]["functions"]); fb=set(full[b]["functions"])
        return sorted(fa-fb), sorted(fb-fa)
    for a,b in [("pair_192","pair_96"),("pair_22","pair_2"),("pair_96","pair_22")]:
        o1,o2=diff(a,b)
        print(f"\n== {a} vs {b}: only-{a}: {o1} only-{b}: {o2}")
    with open(os.path.join(OUT,"class_functions.json"),"w") as fh:
        json.dump(full, fh, indent=1)

if __name__=="__main__":
    main()
