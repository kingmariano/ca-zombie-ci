#!/usr/bin/env bash
# AutoShark deep-dive heavy CI job:
#   - re-derives live pair TVL independently (all 194 FinsFactory pairs)
#   - attributes LP value to protocol contracts
#   - probes every candidate extraction path via eth_call from a fresh EOA
# Results -> ci-out/autoshark_ci_facts.json (uploaded artifact). No secrets in this file.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
RPC="${BSC_RPC_URL:-https://bsc-rpc.publicnode.com}"
export RPC
python3 - <<'PY'
import json, os, time, urllib.request
RPC = os.environ.get("RPC", "https://bsc-rpc.publicnode.com")

def rpc_batch(calls, chunk=50):
    """calls: list of (method, params). Returns list of results (or None on error)."""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc":"2.0","id":j,"method":m,"params":p} for j,(m,p) in enumerate(part)]
        for attempt in range(7):
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                             headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
                res = json.load(urllib.request.urlopen(req, timeout=90))
                if isinstance(res, list):
                    out.extend([r.get("result") for r in res])
                    break
                time.sleep(3+attempt*2)
            except Exception as e:
                print("rpc retry", attempt, str(e)[:80]); time.sleep(3+attempt*2)
        else:
            out.extend([None]*len(part))
    return out

def enc_u(v): return hex(v)[2:].rjust(64,"0")
def enc_a(a): return a.lower().replace("0x","").rjust(64,"0")
def uint(h): return int(h,16) if h and h!="0x" else None
def addr(h): return "0x"+h[-40:] if h and h!="0x" else None

SEL_TS="0x18160ddd"; SEL_T0="0x0dfe1681"; SEL_T1="0xd21220a7"; SEL_RES="0x0902f1ac"; SEL_BAL="0x70a08231"
FACTORY="0xe759Dd4B9f99392Be64f1050a6A8018f73B53a13"
CONTRACTS={
 "feeTo_FeeDistributor":"0x593CC303170367FCB249abdd08Aaaa736d552BA5",
 "feeVault_Squid":"0xe0B4Add509BAB9d04cA92541272C87CDB822FA32",
 "MasterOcean":"0x8857af8205f224870dea119e2c75af386efb192a",
 "MasterSquid":"0x86a47ddd4c6522251d6a5a5800f3f24c03332cb4",
 "jawsPool":"0x5D2112Ba0969EC66012380C1fb88F2A3D182Eb90",
 "launchpad":"0xa9f48fee822530037628fcbbe2d7724221b1536d",
 "team_EOA_fee_receiver":"0x91d6136a45c10a8567ae9e2aac193d65fd4c7e01",
}
facts={"rpc_kind":"env BSC_RPC_URL or public","chain":"bsc","block":"latest"}

blk = rpc_batch([("eth_blockNumber",[])])[0]
facts["block"] = int(blk,16)
n = uint(rpc_batch([("eth_call",[{"to":FACTORY,"data":"0x574f2ba3"},"latest"])])[0])
facts["allPairsLength"] = n
pairs = [addr(x) for x in rpc_batch([("eth_call",[{"to":FACTORY,"data":"0x1e3dd18b"+enc_u(i)},"latest"]) for i in range(n)])]

calls=[]
for p in pairs:
    calls += [("eth_call",[{"to":p,"data":SEL_TS},"latest"]),
              ("eth_call",[{"to":p,"data":SEL_T0},"latest"]),
              ("eth_call",[{"to":p,"data":SEL_T1},"latest"]),
              ("eth_call",[{"to":p,"data":SEL_RES},"latest"])]
for nm,who in CONTRACTS.items():
    for p in pairs:
        calls.append(("eth_call",[{"to":p,"data":SEL_BAL+enc_a(who)},"latest"]))
res = rpc_batch(calls)
k=0
pr={}
for p in pairs:
    ts=uint(res[k]); t0=addr(res[k+1]); t1=addr(res[k+2]); rr=res[k+3]; k+=4
    r0=r1=0
    if rr and rr!="0x":
        b=bytes.fromhex(rr[2:])
        if len(b)>=96: r0=int.from_bytes(b[0:32],"big"); r1=int.from_bytes(b[32:64],"big")
    pr[p]={"token0":t0,"token1":t1,"reserve0":r0,"reserve1":r1,"lp_totalSupply":ts}
for nm in CONTRACTS:
    for p in pairs:
        pr[p]["lp_"+nm]=uint(res[k]); k+=1

# prices + decimals
toks=sorted({v["token0"] for v in pr.values()} | {v["token1"] for v in pr.values()})
dec={}
for i in range(0,len(toks),80):
    ds=rpc_batch([("eth_call",[{"to":t,"data":"0x313ce567"},"latest"]) for t in toks[i:i+80]])
    for t,r in zip(toks[i:i+80],ds):
        dec[t]=uint(r) if r and r!="0x" else 18
prices={}
for i in range(0,len(toks),50):
    q=",".join("bsc:"+t.lower() for t in toks[i:i+50])
    try:
        d=json.load(urllib.request.urlopen("https://coins.llama.fi/prices/current/"+q, timeout=60))
        prices.update(d.get("coins",{}))
    except Exception as e:
        print("price err", str(e)[:80])
def price(t):
    c=prices.get("bsc:"+t.lower()); return c["price"] if c else None
def val(p):
    v=pr[p]; r0,r1=v["reserve0"],v["reserve1"]
    p0,p1=price(v["token0"]),price(v["token1"])
    d0=dec.get(v["token0"],18); d1=dec.get(v["token1"],18)
    return (p0*r0/10**d0 if p0 and r0 else 0)+(p1*r1/10**d1 if p1 and r1 else 0)

total=sum(val(p) for p in pairs)
attrib={nm:0.0 for nm in CONTRACTS}
for p in pairs:
    v=val(p); ts=pr[p]["lp_totalSupply"] or 0
    for nm in CONTRACTS:
        lb=pr[p]["lp_"+nm] or 0
        if ts: attrib[nm]+=v*lb/ts
# read exact decimals for priced tokens to avoid wrong scaling
facts["pair_value_total_usd"]=round(total,2)
facts["attribution_usd"]={k:round(v,2) for k,v in attrib.items()}
facts["top_pairs"]=[]
top=sorted(pairs,key=lambda p:-val(p))[:10]
for p in top:
    facts["top_pairs"].append({"pair":p,"value_usd":round(val(p),2),
        "token0":pr[p]["token0"],"token1":pr[p]["token1"],
        "lp_MasterOcean":pr[p]["lp_MasterOcean"],"lp_MasterSquid":pr[p]["lp_MasterSquid"],
        "lp_feeVault":pr[p]["lp_feeVault_Squid"],"lp_feeTo":pr[p]["lp_feeTo_FeeDistributor"],
        "lp_totalSupply":pr[p]["lp_totalSupply"],"lp_teamEOA":pr[p]["lp_team_EOA_fee_receiver"]})
# excess
ex=[]
for p in pairs:
    v=pr[p]
    if v["reserve0"]:
        b0=uint(rpc_batch([("eth_call",[{"to":v["token0"],"data":SEL_BAL+enc_a(p)},"latest"])])[0]) or 0
        if b0>v["reserve0"]: ex.append({"pair":p,"side":0,"excess_raw":b0-v["reserve0"]})
    if v["reserve1"]:
        b1=uint(rpc_batch([("eth_call",[{"to":v["token1"],"data":SEL_BAL+enc_a(p)},"latest"])])[0]) or 0
        if b1>v["reserve1"]: ex.append({"pair":p,"side":1,"excess_raw":b1-v["reserve1"]})
facts["donation_excess_pairs"]=ex

# ---- gate probes from a fresh EOA ----
ATT="0x00000000000000000000000000000000d34dbeef"
def probe(to, data, tag):
    r = rpc_batch([("eth_call",[{"from":ATT,"to":to,"data":data},"latest"])])[0]
    return {"probe":tag,"to":to,"result":r,"reverted": r is None, "paid_out": r not in (None,"0x")}
gates=[]
gates.append(probe(CONTRACTS["feeTo_FeeDistributor"], "0x6138889b"+enc_u(32)+enc_u(1)+enc_a("0x06347b91DaBc757cCD5A5AA2aF802cEc78e4D239"), "feeTo.distribute([USDT/BUSD])"))
gates.append(probe(CONTRACTS["feeVault_Squid"], "0x7c72d7aa"+enc_u(32)+enc_u(1)+enc_a("0x06347b91DaBc757cCD5A5AA2aF802cEc78e4D239"), "feeVault.distributeSingle([USDT/BUSD])"))
gates.append(probe("0x1b219Aca875f8C74c33CFF9fF98f3a9b62fCbff5", "0xa0712d68"+enc_u(10**18), "FINS.mint(1e18)"))
gates.append(probe("0x1b219Aca875f8C74c33CFF9fF98f3a9b62fCbff5", "0x40c10f19"+enc_a(ATT)+enc_u(10**18), "FINS.mint(attacker,1e18)"))
gates.append(probe("0xdd97ab35e3c0820215bc85a395e13671d84ccba2", "0x40c10f19"+enc_a(ATT)+enc_u(10**18), "JAWS.mint(attacker,1e18)"))
gates.append(probe("0xAE61e7dc989718E700C046a2483e93513eDCA484", "0xa0712d68"+enc_u(10**18), "SQUID.mint(1e18)"))
gates.append(probe(CONTRACTS["MasterOcean"], "0x441a3e70"+enc_u(25)+enc_u(10**15), "MasterOcean.withdraw(25,1e15)"))
gates.append(probe(CONTRACTS["MasterSquid"], "0x441a3e70"+enc_u(3)+enc_u(10**15), "MasterSquid.withdraw(3,1e15)"))
gates.append(probe(CONTRACTS["jawsPool"], "0x2e1a7d4d"+enc_u(10**18), "jawsPool.withdraw(1e18)"))
gates.append(probe(CONTRACTS["jawsPool"], "0x3d18b912", "jawsPool.getReward()"))
gates.append(probe(CONTRACTS["launchpad"], "0x4641257d", "launchpad.harvest()"))
gates.append(probe(CONTRACTS["launchpad"], "0x9f1b5248"+enc_u(0)+enc_u(0), "launchpad.finalWithdraw(0,0)"))
facts["gate_probes"]=gates
facts["gates_all_reverted"]=all(g["reverted"] or not g["paid_out"] for g in gates if "withdraw(25" in g["probe"] or "withdraw(3" in g["probe"] or "distribute" in g["probe"] or "mint" in g["probe"] or "harvest" in g["probe"] or "finalWithdraw" in g["probe"])

with open("ci-out/autoshark_ci_facts.json","w") as f:
    json.dump(facts,f,indent=1)
print(json.dumps({k:facts[k] for k in ["block","allPairsLength","pair_value_total_usd","attribution_usd","gates_all_reverted"]},indent=1))
print("donation pairs:",len(facts["donation_excess_pairs"]))
for g in gates: print(("REVERT" if g["reverted"] else "OK   "), g["probe"])
bad=[g for g in gates if g["probe"].split(".")[0] in ("feeTo","feeVault","FINS","JAWS","SQUID","MasterOcean","MasterSquid","jawsPool","launchpad") and not g["reverted"]]
# mints/distribute/foreign-withdraw MUST revert; jawsPool withdraw may revert or return empty
must_revert=[g for g in gates if any(s in g["probe"] for s in ["distribute","mint(","withdraw(25","withdraw(3","harvest","finalWithdraw"])]
if any(not g["reverted"] for g in must_revert):
    print("FAIL: a gated path did NOT revert:", [g["probe"] for g in must_revert if not g["reverted"]])
    raise SystemExit(1)
print("ALL GATED PROBES REVERTED AS EXPECTED")
PY
echo "[ci] autoshark facts written to ci-out/"
ls -la ci-out/
