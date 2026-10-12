#!/usr/bin/env python3
"""CI state verification for Rift Finance (keyless public RPCs only; no secrets; read-only).
Writes ci-out/verify.json and ci-out/verify-summary.txt."""
import json, os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPCS = {"ethereum": ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org"],
        "aurora": ["https://mainnet.aurora.dev", "https://aurora.drpc.org"]}

SEL = {"token0": "0x0dfe1681", "token1": "0xd21220a7", "pair": "0xa8aa1b31", "epoch": "0x900cf0cf",
       "lastEpochStart": "0xd5bf91e3", "paused": "0x5c975abb", "core": "0xf2f4eb26",
       "token0Data": "0xac896951", "token1Data": "0x930f7ee8", "epochDuration": "0x4ff0876a",
       "feesAccrued": "0x94db0595", "depositsEnabled": "0x5392fd1c", "totalSupply": "0x18160ddd",
       "getReserves": "0x0902f1ac", "balanceOf": "0x70a08231", "symbol": "0x95d89b41", "decimals": "0x313ce567"}

V = {
 "ethereum": ["0x51c6f3433e8ff88726c09950add24726c28264d3","0x40d23398d9d553c1406d44ce020e15b702b308e4",
   "0x5a999fed5bd99f8a6a30cb1d411f689390514a61","0x820fb78054e966bee5e7d0421cb949cba137bcf4",
   "0x95f635a4116a805e83433b455eeb9a60ee025408","0xe914b3e4adf87dbf5ff35895f8aef5b169f82c9a",
   "0x01ebd85a8ed9cdb99e17550ffc35b3d1e1c07fd6","0x969a4a1f3dd4bb66ecbbf7b09e93c28f53d06e2a",
   "0x01875b967583cc3ce5046c1321b752c0baf05fbd"],
 "aurora": ["0xc8ddc0ad618e8f293d773917738c065a0ed44384","0x40d23398d9d553c1406d44ce020e15b702b308e4",
   "0xe914b3e4adf87dbf5ff35895f8aef5b169f82c9a","0x2c72be54f04cbbbf816a87530ae2ed878bb04455",
   "0x5a999fed5bd99f8a6a30cb1d411f689390514a61","0x8ef6069046af6fd9043f22b2633fcff38991e5b4",
   "0xd51ccf4208d36d13fedc5f6a729db69138dcf04f","0xb31142aff04cf4ce4f5fdc5458b03a93db274ad4"],
}

def pick_rpc(chain):
    for u in RPCS[chain]:
        try:
            req = urllib.request.Request(u, json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"rift-ci"})
            r = json.loads(urllib.request.urlopen(req, timeout=20).read())
            if "result" in r: return u, int(r["result"],16)
        except Exception: pass
    raise RuntimeError("no rpc for "+chain)

def batch(url, calls, chunk=25):
    out=[]
    for i in range(0,len(calls),chunk):
        part=calls[i:i+chunk]
        payload=[{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[{"to":t,"data":d},"latest"]} for j,(t,d) in enumerate(part)]
        req=urllib.request.Request(url, json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"rift-ci"})
        res=json.loads(urllib.request.urlopen(req, timeout=120).read())
        m={x["id"]:x for x in res}
        for j in range(len(part)):
            x=m.get(j,{}); out.append(x.get("result") if "result" in x else None)
    return out

def num(h):
    try: return int(h,16)
    except Exception: return None

def addr(h):
    return "0x"+h[-40:] if h and h.startswith("0x") and len(h)>=42 else None

def sdec(h):
    try:
        b=bytes.fromhex(h[2:]); ln=int.from_bytes(b[32:64],'big'); return b[64:64+ln].decode()
    except Exception: return None

def balance_of(tok, holder):
    return SEL["balanceOf"]+"0"*24+holder[2:]

def main():
    os.makedirs("ci-out", exist_ok=True)
    result={"chains":{}}
    for chain in ("ethereum","aurora"):
        url, blk = pick_rpc(chain)
        vaults=V[chain]
        calls=[]; keys=[]
        for v in vaults:
            for k in ("token0","token1","pair","epoch","lastEpochStart","paused","token0Data","token1Data","feesAccrued"):
                calls.append((v,SEL[k])); keys.append((v,k))
        res=batch(url,calls)
        st={}
        for (v,k),r in zip(keys,res): st.setdefault(v,{})[k]=r
        toks=set()
        for v in vaults:
            for k in ("token0","token1"):
                a=addr(st[v].get(k) or ""); 
                if a: toks.add(a.lower())
        pairs=set()
        for v in vaults:
            p=addr(st[v].get("pair") or "")
            if p: pairs.add(p.lower())
        mc=[]; mk=[]
        for t in sorted(toks): mc += [(t,SEL["symbol"]),(t,SEL["decimals"])]; mk += [("sym",t),("dec",t)]
        for p in sorted(pairs): mc += [(p,SEL["token0"]),(p,SEL["token1"]),(p,SEL["getReserves"]),(p,SEL["totalSupply"])]; mk += [("p0",p),("p1",p),("res",p),("ts",p)]
        mr=batch(url,mc)
        M={}
        for (k,t),r in zip(mk,mr): M.setdefault(t,{})[k]=r
        tinfo={}
        for t in sorted(toks):
            tinfo[t]={"symbol":sdec(M[t].get("sym") or "0x"), "decimals":num(M[t].get("dec") or "0x0") or 18}
        pinfo={}
        for p in sorted(pairs):
            r=M[p].get("res") or ""
            if len(r)>=130: r0=int(r[2:66],16); r1=int(r[66:130],16)
            else: r0=r1=None
            pinfo[p]={"token0":addr(M[p].get("p0") or ""),"token1":addr(M[p].get("p1") or ""),
                      "reserve0":r0,"reserve1":r1,"totalSupply":num(M[p].get("ts"))}
        bc=[]; bk=[]
        for v in vaults:
            t0=addr(st[v]["token0"]); t1=addr(st[v]["token1"]); p=addr(st[v]["pair"])
            for tok,kk in ((t0,"bal0"),(t1,"bal1"),(p,"balLP")):
                if tok: bc.append((tok,balance_of(tok,v))); bk.append((v,kk))
        br=batch(url,bc)
        B={}
        for (v,kk),r in zip(bk,br): B.setdefault(v,{})[kk]=num(r)
        ids=[f"{chain}:{t}" for t in sorted(toks)]
        pr=json.loads(urllib.request.urlopen(urllib.request.Request("https://coins.llama.fi/prices/current/"+",".join(ids),
            headers={"User-Agent":"rift-ci"}),timeout=60).read())
        prices={k.split(":")[1]:v["price"] for k,v in pr.get("coins",{}).items()}
        out={"block":blk,"rpc_note":"keyless public","tokens":tinfo,"vaults":{}}
        total=0.0
        for v in vaults:
            t0=addr(st[v]["token0"]); t1=addr(st[v]["token1"]); p=addr(st[v]["pair"])
            w=st[v]["token0Data"]; w1=st[v]["token1Data"]
            def words(h):
                return [num("0x"+h[2+i*64:2+(i+1)*64]) for i in range(5)] if h and h.startswith("0x") else [None]*5
            w0=words(w); ww1=words(w1)
            f=words(st[v]["feesAccrued"])
            dec0=tinfo[t0]["decimals"]; dec1=tinfo[t1]["decimals"]
            e={"token0":t0,"token1":t1,"pair":p,"sym0":tinfo[t0]["symbol"],"sym1":tinfo[t1]["symbol"],
               "epoch":num(st[v]["epoch"]),"lastEpochStart":num(st[v]["lastEpochStart"]),
               "paused":st[v]["paused"].endswith("1") if st[v]["paused"] else None,
               "token0Data":dict(zip(["reserves","active","depositRequestsTotal","withdrawRequestsTotal","claimableTotal"],w0)),
               "token1Data":dict(zip(["reserves","active","depositRequestsTotal","withdrawRequestsTotal","claimableTotal"],ww1)),
               "feesAccrued":[f[0],f[1]],
               "bal0":B[v].get("bal0"),"bal1":B[v].get("bal1"),"balLP":B[v].get("balLP")}
            usd=0.0
            p0=prices.get(t0); p1=prices.get(t1)
            if e["bal0"] and p0: usd += e["bal0"]/10**dec0*p0
            if e["bal1"] and p1: usd += e["bal1"]/10**dec1*p1
            if p in pinfo and pinfo[p]["totalSupply"] and e["balLP"]:
                share=e["balLP"]/pinfo[p]["totalSupply"]
                r0,r1=pinfo[p]["reserve0"],pinfo[p]["reserve1"]
                a0,a1=(r0,r1) if pinfo[p]["token0"]==t0 else (r1,r0)
                e["lp_share"]=share; e["lp_t0"]=a0*share if a0 else None; e["lp_t1"]=a1*share if a1 else None
                if a0 and p0: usd += a0*share/10**dec0*p0
                if a1 and p1: usd += a1*share/10**dec1*p1
            e["usd"]=round(usd,2)
            total+=usd
            out["vaults"][v]=e
        out["usd_total"]=round(total,2)
        result["chains"][chain]=out
    with open("ci-out/verify.json","w") as fh: json.dump(result,fh,indent=1)
    lines=[]
    for chain,d in result["chains"].items():
        lines.append(f"{chain} block {d['block']} usd_total {d['usd_total']}")
        for v,e in d["vaults"].items():
            lines.append(f"  {v} {e['sym0']}/{e['sym1']} paused={e['paused']} usd={e['usd']} bal0={e['bal0']} bal1={e['bal1']} balLP={e['balLP']} claimable0={e['token0Data']['claimableTotal']} claimable1={e['token1Data']['claimableTotal']}")
    open("ci-out/verify-summary.txt","w").write("\n".join(lines)+"\n")
    print("\n".join(lines))

if __name__=="__main__":
    main()
