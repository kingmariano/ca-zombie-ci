#!/usr/bin/env python3
"""Enumerate ALL holders of Nerve base LP tokens (GoldRush/Covalent),
then find every EIP-1167 clone of the Nerve MetaSwap impls among them.
This catches metapools the prior may have missed (complete token1-holder sweep)."""
import json, urllib.request, os, time, sys

KEY = os.environ.get("GOLD_RUSH_API_KEY","")
OUT = "/home/heisenberg/CA/nerve-qc/analysis"

def http(url, tries=5):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent":"research/1.0"})
            return json.load(urllib.request.urlopen(req, timeout=60))
        except Exception as e:
            if i == tries-1: raise
            time.sleep(2+2*i)

def holders(token):
    got = {}
    page = 1
    for _ in range(50):
        url = f"https://api.covalenthq.com/v1/56/tokens/{token}/token_holders_v2/?key={KEY}&page-size=100&page-number={page}"
        d = http(url)
        data = d.get("data") or {}
        items = data.get("items") or []
        if not items: break
        for it in items:
            addr = (it.get("address") or it.get("holder_address") or "").lower()
            if not addr:
                # inspect first item keys once
                sys.stderr.write("item keys: %s\n" % list(it.keys()))
                continue
            got[addr] = it.get("balance")
        pag = data.get("pagination") or {}
        if not pag.get("has_more"): break
        page = pag.get("next_page") or (page+1)
    return got

LP_TOKENS = {
 "LP3":  "0xf2511b5e4fb0e5e2d123004b672ba14850478c14",
 "BTCLP":"0xd1d5af92c606c6f2ec59d453f57a6fcc188d7db5",
 "ETHLP":"0x0d283bf16a9bde49cfc48d8dc050af28b71bdd90",
}

def main():
    allh = {}
    for name, t in LP_TOKENS.items():
        try:
            h = holders(t)
            allh[name] = h
            print(f"{name}: {len(h)} holders")
        except Exception as e:
            print(f"{name} ERROR {e}")
    with open(f"{OUT}/lp_holders.json","w") as f:
        json.dump(allh, f, indent=2)
    # check code of each holder
    RPC = None
    key = os.environ.get("ANKR_API_KEY")
    if key: RPC = f"https://rpc.ankr.com/bsc/{key}"
    else: RPC = "https://bsc-rpc.publicnode.com"
    def rpc(m,p):
        req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
        return json.load(urllib.request.urlopen(req,timeout=30)).get("result")
    uniq = sorted({a for h in allh.values() for a in h})
    print("unique holder addresses:", len(uniq))
    clones = {}
    for a in uniq:
        c = rpc("eth_getCode",[a,"latest"])
        if not c or c=="0x": continue
        if len(c) == 2+90 and c.startswith("0x363d3d373d3d3d363d73"):
            impl = "0x"+c[2+20:2+60]
            clones[a] = impl
    print("EIP-1167 clones among LP holders:", len(clones))
    for a,i in sorted(clones.items(), key=lambda x: x[1]):
        print(f"  {a} -> {i}")
    with open(f"{OUT}/clones_from_holders.json","w") as f:
        json.dump(clones, f, indent=2)

if __name__=="__main__":
    if not KEY: raise SystemExit("no key")
    main()
