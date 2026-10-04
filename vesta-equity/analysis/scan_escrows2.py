import requests, json, time, hashlib, base64
from concurrent.futures import ThreadPoolExecutor
B="https://mainnet-idx.algonode.cloud"
cands=json.load(open("escrow_scan.json")).keys()
cands=[a for a in cands]
print("candidates:",len(cands),flush=True)
def fetch(addr):
    out={"addr":addr}
    try:
        a=requests.get(f"{B}/v2/accounts/{addr}",timeout=25).json().get("account",{})
        out["amount"]=a.get("amount"); out["assets"]=[(x["asset-id"],x["amount"],x.get("is-frozen")) for x in a.get("assets",[])]
        out["auth"]=a.get("auth-addr"); out["created_apps"]=[x["id"] for x in a.get("created-apps",[])]
        lr=requests.get(f"{B}/v2/accounts/{addr}/transactions",params={"limit":100,"sig-type":"lsig"},timeout=25).json().get("transactions",[])
        if lr:
            out["lsig"]=True
            progs=set()
            for tx in lr:
                lg=tx.get("signature",{}).get("logicsig",{})
                if lg.get("logic"): progs.add(lg["logic"])
            out["n_lsig"]=len(lr); out["n_progs"]=len(progs)
            out["progs"]=[base64.b64encode(hashlib.sha256(base64.b64decode(p)).digest()).decode()[:16] for p in progs]
            out["prog_b64"]=sorted(progs)[0]
        else:
            out["lsig"]=False
            tr=requests.get(f"{B}/v2/accounts/{addr}/transactions",params={"limit":100},timeout=25).json().get("transactions",[])
            out["n_txs"]=len(tr)
            out["n_sig"]=sum(1 for tx in tr if "sig" in tx.get("signature",{}))
            out["n_lsig_any"]=sum(1 for tx in tr if "logicsig" in tx.get("signature",{}))
            if out["n_lsig_any"]:
                out["lsig"]=True
                for tx in tr:
                    lg=tx.get("signature",{}).get("logicsig",{})
                    if lg.get("logic"): out["prog_b64"]=lg["logic"]; break
    except Exception as e:
        out["error"]=str(e)
    return out
res=[]
with ThreadPoolExecutor(max_workers=8) as ex:
    for r in ex.map(fetch,cands):
        res.append(r)
json.dump(res,open("escrow_scan2.json","w"),indent=1)
ls=[r for r in res if r.get("lsig")]
keyed=[r for r in res if not r.get("lsig") and r.get("n_sig",0)>0]
noout=[r for r in res if not r.get("lsig") and r.get("n_sig",0)==0 and not r.get("error")]
print("total",len(res),"lsig",len(ls),"keyed",len(keyed),"no-outgoing",len(noout),flush=True)
print("lsig addrs:",[r["addr"][:14] for r in ls])
print("no-outgoing with funds:",[(r["addr"][:14],r.get("amount")) for r in noout if (r.get("amount") or 0)>0],flush=True)
print("lsig with funds:",[(r["addr"][:14],r.get("amount"),r.get("assets")) for r in ls],flush=True)
