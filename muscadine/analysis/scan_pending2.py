#!/usr/bin/env python3
"""Pending-timelock scan with thread pool; drpc public + ankr fallback. No secrets persisted."""
import json, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

KEY = os.environ.get("ANKR_API_KEY","")
RPCS = ["https://base.drpc.org", "https://mainnet.base.org"] + ([f"https://rpc.ankr.com/base/{KEY}"] if KEY else [])

def one(to, data, tries=6):
    for a in range(tries):
        rpc = RPCS[a % len(RPCS)]
        payload = {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}
        req = urllib.request.Request(rpc, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        try:
            out = json.load(urllib.request.urlopen(req, timeout=30))
            if "result" in out and out["result"] is not None:
                return int(out["result"],16)
        except Exception:
            pass
        time.sleep(0.4*(a+1))
    return None

def enc_bytes(b):
    if b.startswith("0x"): b = b[2:]
    return "20".rjust(64,"0") + hex(len(b)//2)[2:].rjust(64,"0") + b.ljust((len(b)+63)//64*64,'0')

d = json.load(open("events-scan.json"))
VAULT = {
 "usdc_prime":"0x89712980cb434ef5ae4ab29349419eb976b0b496",
 "weth_prime":"0xd6dcad2f7da91fbb27bda471540d9770c97a5a43",
 "cbbtc_prime":"0x99dcd0d75822ba398f13b2a8852b07c7e137ec70",
 "usdc_frontier":"0x314fD07319ef645bA7D548915CCd91F4788A1839",
}
EXEC="0x8639fb07"
out={}
for cname, addr in VAULT.items():
    subs = d["events"].get(cname,{}).get("Submit",[])
    datas={}
    for lg in subs:
        data=lg["data"][2:]
        off=int(data[0:64],16); ln=int(data[off*2:off*2+64],16)
        raw="0x"+data[off*2+64:off*2+64+ln*2]
        datas[raw]=int(lg["blockNumber"],16)
    items=sorted(datas.items(), key=lambda kv:-kv[1])
    results={}
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs={ex.submit(one, addr, EXEC+enc_bytes(raw)): raw for raw,_ in items}
        for f in as_completed(futs):
            results[futs[f]]=f.result()
    pend=[]; unknown=[]
    for raw,blk in items:
        v=results.get(raw)
        if v is None: unknown.append(raw)
        elif v!=0: pend.append({"data":raw,"executableAt":v,"submitted_blk":blk})
    out[cname]={"n_unique":len(datas),"pending":pend,"unknown":unknown}
    print(f"{cname}: {len(datas)} unique, {len(pend)} PENDING, {len(unknown)} unknown", flush=True)
    for p in pend:
        print("   ", p["data"][:220], "execAt", p["executableAt"], "blk", p["submitted_blk"], flush=True)
json.dump(out, open("pending-final.json","w"), indent=1)
print("saved pending-final.json")
