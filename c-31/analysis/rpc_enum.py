#!/usr/bin/env python3
"""Batch-read Yearn v1 registry + known iEarn/v1 vaults via JSON-RPC (read-only)."""
import json, sys, urllib.request, time

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"
BLOCK = sys.argv[2] if len(sys.argv) > 2 else "latest"
if BLOCK.isdigit(): BLOCK = hex(int(BLOCK))
OUT = sys.argv[3] if len(sys.argv) > 3 else "v1_full.json"

REG = "0x3eE41C098f9666ed2eA246f4D2558010e59d63A0"
SEL = {
 "name":"0x06fdde03","symbol":"0x95d89b41","decimals":"0x313ce567","totalSupply":"0x18160ddd",
 "getPricePerFullShare":"0x77c7b8fc","token":"0xfc0c546a","want":"0x1f1fcd51","balance":"0xb69ef8a8",
 "controller":"0xf77c4791","governance":"0x5aa6e675","strategy":"0xa8c62e76",
 "calcPoolValueInToken":"0x7137ef99","totalAssets":"0x01e1d114","pricePerShare":"0x99530b06",
 "getVaultsLength":"0x44b19dfc","getVault":"0x9403b634",
}
EXTRA_VAULTS = ["0x16de59092dae5ccf4a1e6439d611fd0653f0bd01","0xd6ad7a6750a7593e092a9b218d66c0a814a3436e",
 "0x83f798e925bcd4017eb265844fddabb448f1707d","0x73a052500105205d34daf004eab301916da8190f"]

def rpc_batch(calls):
    """calls: list of (to, data) -> results list"""
    payload = []
    for i,(to,data) in enumerate(calls):
        payload.append({"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data}, BLOCK]})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"research"})
    for attempt in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=60))
            break
        except Exception as e:
            print("retry", e, file=sys.stderr); time.sleep(2)
    else:
        raise RuntimeError("rpc failed")
    byid = {x["id"]:x for x in r}
    return [byid[i].get("result") for i in range(len(calls))]

def enc_uint(i):
    return hex(i)[2:].rjust(64,"0")

def dec_string(hexstr):
    if not hexstr or hexstr == "0x": return None
    b = bytes.fromhex(hexstr[2:])
    if len(b) >= 64:
        off = int.from_bytes(b[0:32],"big")
        if off+32 <= len(b):
            ln = int.from_bytes(b[off:off+32],"big")
            s = b[off+32:off+32+ln]
            try: return s.decode()
            except: return None
    return None

def main():
    # registry length
    r = rpc_batch([(REG, SEL["getVaultsLength"])])
    n = int(r[0],16)
    vaults = []
    # fetch vault addresses in one batch
    calls = [(REG, "0x9403b634"+enc_uint(i)) for i in range(n)]
    res = rpc_batch(calls)
    for x in res:
        if x and int(x,16) != 0:
            vaults.append("0x"+x[-40:])
    vaults += EXTRA_VAULTS
    print(f"registry vaults: {n}, total incl extras: {len(vaults)}", file=sys.stderr)
    data = {}
    # batch all functions for all vaults
    calls=[]; meta=[]
    for v in vaults:
        for fn,sel in SEL.items():
            calls.append((v, sel)); meta.append((v,fn))
    res = rpc_batch(calls)
    for (v,fn),r in zip(meta,res):
        d = data.setdefault(v,{})
        if r and r != "0x":
            if fn in ("name","symbol"):
                d[fn] = dec_string(r)
            else:
                d[fn] = int(r,16)
        else:
            d[fn] = None
    out = {"rpc":RPC, "block":BLOCK, "registry":REG, "vaults":data}
    with open(OUT,"w") as f: json.dump(out,f,indent=1)
    print(json.dumps(out,indent=1)[:200])
    print("wrote", OUT)

if __name__ == "__main__":
    main()
