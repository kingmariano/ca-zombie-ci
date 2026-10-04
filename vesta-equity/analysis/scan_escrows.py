import requests, json, time, hashlib, base64
from concurrent.futures import ThreadPoolExecutor
B="https://mainnet-idx.algonode.cloud"
txs=json.load(open("rqi_all_txs.json"))
recv=set()
for t in txs:
    if t["tx-type"]=="pay":
        pt=t.get("payment-transaction",{})
        if pt.get("amount") in (325000,225000,205000,310000):
            recv.add(pt.get("receiver"))
recv.discard(None); recv.discard("RQIQQIHYGFF4NR5ODLSYMK5EGETHCYZT2YDAILPW4MNEBF4OUTJTMWDSOI")
print("candidate accounts:",len(recv),flush=True)
def fetch(addr):
    try:
        a=requests.get(f"{B}/v2/accounts/{addr}",timeout=25).json().get("account",{})
        t=requests.get(f"{B}/v2/accounts/{addr}/transactions",params={"limit":10},timeout=25).json().get("transactions",[])
    except Exception as e:
        return addr,{"error":str(e)}
    progs=[]
    for tx in t:
        sig=tx.get("signature",{})
        if "logicsig" in sig and sig["logicsig"].get("logic"):
            progs.append(sig["logicsig"]["logic"])
    phash=None; computed=None
    if progs:
        raw=base64.b64decode(progs[0])
        phash=hashlib.sha256(raw).hexdigest()[:16]
        ar=hashlib.new('sha512_256', b"Program"+raw).digest()
        chk=hashlib.new('sha512_256', ar).digest()[-4:]
        computed=base64.b32encode(ar+chk).decode().rstrip('=')
    return addr,{
      "amount":a.get("amount"),"auth":a.get("auth-addr"),"status":a.get("status"),
      "created_apps":[x["id"] for x in a.get("created-apps",[])],
      "optin_apps":[x["id"] for x in a.get("apps-local-state",[])][:5],
      "assets":[(x["asset-id"],x["amount"],x.get("is-frozen")) for x in a.get("assets",[])],
      "n_lsig_txs":sum(1 for tx in t if "logicsig" in tx.get("signature",{})),
      "prog_hash":phash,"computed_addr":computed,"addr_match":(computed==addr if computed else None),
      "prog_b64":progs[0] if progs else None,
    }
results={}
with ThreadPoolExecutor(max_workers=8) as ex:
    for addr,r in ex.map(fetch,sorted(recv)):
        results[addr]=r
json.dump(results,open("escrow_scan.json","w"),indent=1)
lsigs=[(a,r) for a,r in results.items() if r.get("prog_b64")]
print("total candidates:",len(results),"with lsig program:",len(lsigs),flush=True)
from collections import Counter
print("prog hash counts:",Counter(r["prog_hash"] for a,r in lsigs),flush=True)
print("addr_match all:",all(r["addr_match"] for a,r in lsigs),flush=True)
print("total ALGO micro:",sum(r.get("amount") or 0 for r in results.values()),flush=True)
print("with USDC:",[(a[:14],r["amount"],[x for x in r["assets"] if x[0]==31566704]) for a,r in results.items() if any(x[0]==31566704 and x[1]>0 for x in r.get("assets",[]))],flush=True)
print("with VST:",[(a[:14],r["amount"],[x for x in r["assets"] if x[0] in (1135235829,1144192990)]) for a,r in results.items() if any(x[0] in (1135235829,1144192990) for x in r.get("assets",[]))],flush=True)
