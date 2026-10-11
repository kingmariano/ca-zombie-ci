#!/usr/bin/env python3
"""Check pending timelocked actions + roles + whitelist gate state (read-only, batched)."""
import json, os, sys, time, urllib.request

KEY = os.environ.get("ANKR_API_KEY")
if not KEY: sys.exit("ANKR_API_KEY not set")
RPC = f"https://rpc.ankr.com/base/{KEY}"
FALLBACK = "https://base.drpc.org"

def rpc_batch(calls, tries=4, chunk=15):
    results = []
    for i in range(0, len(calls), chunk):
        sub = calls[i:i+chunk]
        res = None
        for a in range(tries):
            rpc = RPC if a < 3 else FALLBACK
            payload = [{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[{"to":t,"data":d},"latest"]} for j,(t,d) in enumerate(sub)]
            req = urllib.request.Request(rpc, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            try:
                out = json.load(urllib.request.urlopen(req, timeout=60))
                m = {it["id"]: it.get("result") for it in out}
                res = [m.get(j) for j in range(len(sub))]
                break
            except Exception as e:
                print("batch fail:", str(e)[:60], file=sys.stderr); time.sleep(1.5*(a+1))
        if res is None:
            res = [None]*len(sub)
        results.extend(res)
    return results

def pad_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def pad_uint(n): return hex(n)[2:].rjust(64,"0")
def enc_bytes(b): return pad_uint(0x20)+pad_uint(len(b)//2)+b.ljust((len(b)+63)//64*64,'0')

d = json.load(open("events-scan.json"))
VAULT_ADDR = {
 "usdc_prime":"0x89712980cb434ef5ae4ab29349419eb976b0b496",
 "weth_prime":"0xd6dcad2f7da91fbb27bda471540d9770c97a5a43",
 "cbbtc_prime":"0x99dcd0d75822ba398f13b2a8852b07c7e137ec70",
 "usdc_frontier":"0x314fD07319ef645bA7D548915CCd91F4788A1839",
}
EXEC_SEL = "0x8639fb07"
out = {"pending": {}, "roles": {}, "gate": {}, "safes": {}}

print("=== PENDING timelocked actions ===", flush=True)
for cname, addr in VAULT_ADDR.items():
    subs = d["events"].get(cname, {}).get("Submit", [])
    datas = {}
    for lg in subs:
        data = lg["data"][2:]
        off = int(data[0:64],16); ln = int(data[off*2:off*2+64],16)
        raw = "0x" + data[off*2+64:off*2+64+ln*2]
        datas[raw] = int(lg["blockNumber"],16)
    raws = list(datas.keys())
    calls = [(addr, EXEC_SEL + enc_bytes(r)) for r in raws]
    res = rpc_batch(calls)
    pend = []
    for raw, r in zip(raws, res):
        if r and int(r,16) != 0:
            pend.append({"data": raw, "executableAt": int(r,16), "submitted_blk": datas[raw]})
    out["pending"][cname] = pend
    print(f"{cname}: {len(raws)} unique submits, {len(pend)} still pending", flush=True)
    for p in pend:
        print("   ", p["data"][:180], "execAt", p["executableAt"], "blk", p["submitted_blk"], flush=True)

print("=== roles ===", flush=True)
OWNER="0x4e5d3ef790c75682ac4f6d4c1ddcc08b36fc100a"; CURATOR="0xb6d1d784e9bc3570546e231cacb52b4e0f1ed8b1"
ACTORS=["0xf35b121ba32cbeaa27716abeffb6b65a55f9b333","0x0d5a708b651fee1daa0470431c4262ab3e1d0261","0x2ed45bb3542d06d81d117acd8a561e910a17a618","0xaed282b8ad9257bb1272e93ae63a32a53621e412"]
calls=[]; meta=[]
for cname,addr in VAULT_ADDR.items():
    for a in ACTORS:
        calls.append((addr,"0x4dedf20e"+pad_addr(a))); meta.append((cname,a,"alloc"))
        calls.append((addr,"0xba03a75f"+pad_addr(a))); meta.append((cname,a,"sent"))
    for name,sel in [("recvShares","0x98c9b49c"),("sendShares","0x8e511e4d"),("recvAssets","0x0d326b18"),("sendAssets","0x20fe8d58")]:
        calls.append((addr,sel+pad_addr("0x000000000000000000000000000000000000dEaD"))); meta.append((cname,"0xdead",name))
res = rpc_batch(calls)
for (cname,a,kind), r in zip(meta,res):
    val = int(r,16) if r else None
    if kind in ("alloc","sent"): out["roles"].setdefault(cname,{})[f"{a}:{kind}"]=val
    else: out["gate"].setdefault(cname,{})[f"can{kind}(0xdead)"]=val
    print(f"  {cname} {a[:12]}.. {kind} = {val}", flush=True)

print("=== whitelist gate ===", flush=True)
G="0xb7f2598ac79a3c6406dddb81edcc60ea72a134b9"
calls=[(G,"0x3f6481ad")]; meta=[("roleSetter",)]
for a in [OWNER,CURATOR,"0x628037c2d25f5e5f6f90415cff6d7e8860f41c08","0x9e284c8aa44132c911140950d93e44f027199cc5","0xe11ef8ee62a4b395fd1163036e5412eda7db0918","0x48db1f53ea51e37ffe10e59f1df7dc38e52be80e","0xf35b121ba32cbeaa27716abeffb6b65a55f9b333","0x2ed45bb3542d06d81d117acd8a561e910a17a618","0x036A01eFdDC87F6634FFDE0533EE528b90fc7A45","0x54D8417bD21C86A7806b58f5aa2e2E0bB88B856A"]:
    calls.append((G,"0x3af32abf"+pad_addr(a))); meta.append((a,"whitelisted"))
    calls.append((G,"0x692bf818"+pad_addr(a))); meta.append((a,"intermediary"))
res = rpc_batch(calls)
for m,r in zip(meta,res):
    val = "0x"+r[-40:] if (r and len(r)>=42 and m[0]=="roleSetter") else (int(r,16) if r else None)
    out["gate"][str(m)]=val
    print("  ", m, "=", val, flush=True)

print("=== safes ===", flush=True)
for name,a in [("owner",OWNER),("curator",CURATOR),("guardian","0x64e804eef4f5a53272a8623b563ad2724e98a0a9")]:
    res = rpc_batch([(a,"0xe75235b8"),(a,"0xa0e67e2b")])
    th, r = res
    owners=[]
    if r and len(r)>130:
        off=int(r[2:66],16); ln=int(r[2+off*2:2+off*2+64],16)
        owners=["0x"+r[2+off*2+64+i*64+24:2+off*2+64+i*64+64] for i in range(ln)]
    out["safes"][name]={"address":a,"threshold":int(th,16) if th else None,"owners":owners}
    print(" ", name, a, "threshold", int(th,16) if th else None, "owners", owners, flush=True)

json.dump(out, open("pending-roles.json","w"), indent=1)
print("saved pending-roles.json")
