#!/usr/bin/env python3
"""Pinned-block Moola snapshot + liquidatable-position profit estimate.
Read-only. Usage: python3 snapshot_pinned.py <block>
"""
import json, sys, time, urllib.request

BLOCK = int(sys.argv[1]) if len(sys.argv) > 1 else 79583113
HEXB = hex(BLOCK)
RPCS = ["https://forno.celo.org", "https://celo-rpc.publicnode.com"]
POOL = "0x970b12522CA9b4054807a2c5B736149a5BE6f670"
RESERVES = {
 "CELO":  "0x471EcE3750Da237f93B8E339c536989b8978a438",
 "cUSD":  "0x765DE816845861e75A25fCA122bb6898B8B1282a",
 "cEUR":  "0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73",
 "cREAL": "0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787",
 "MOO":   "0x17700282592D6917F6A73D0bF8AcCf4D578c131e",
}
A = {"CELO":"0x7D00cd74FF385c955EA3d79e47BF06bD7386387D","cUSD":"0x918146359264C492BD6934071c6Bd31C854EDBc3",
     "cEUR":"0xE273Ad7ee11dCfAA87383aD5977EE1504aC07568","cREAL":"0x9802d866fdE4563d088a6619F7CeF82C0B991A55",
     "MOO":"0x3A5024E3AAB31A1d3184127B52b0e4B4E9ADcC34"}
VD = {"CELO":"0xAF451D23d6f0FA680113CE2D27a891Aa3587f0C3","cUSD":"0xf602D9617564C07f1e128687798D8C699cED3961",
      "cEUR":"0xfb6c830c13D8322b31b282Ef1Fe85cbb669d9aE8","cREAL":"0xbd408042909351B649DC50353532dEeF6De9fAA9",
      "MOO":"0x3d6d8A1562ff973aD89887C0a5c001f42Ad66CB8"}
SD = {"CELO":"0x02661dd90c6243Fe5cdF88De3E8cb74BcC3bD25E","cEUR":"0x612599D8421F36b7dA4dDBA201a3854FF55e3d03",
      "MOO":"0x0bb14E95a4FF117F7f536D605E2B506e937619C4"}
LIQ_BONUS = {"CELO":10500,"cUSD":10500,"cEUR":11000,"cREAL":11000,"MOO":11000}  # bps
RESERVE_PCT = 200  # bps treasury cut

_rpc_i = 0
def rpc_batch(calls):
    """calls: [(to,data)]; block pinned."""
    global _rpc_i
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":t,"data":d},HEXB]}
               for i,(t,d) in enumerate(calls)]
    for attempt in range(6):
        rpc = RPCS[_rpc_i % len(RPCS)]
        try:
            req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                headers={"Content-Type":"application/json","User-Agent":"moola-audit/1.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.load(r)
            res=[None]*len(calls)
            for it in out: res[it["id"]]=it.get("result")
            if any(x is None for x in res): raise RuntimeError("nulls")
            return res
        except Exception as e:
            _rpc_i += 1; time.sleep(1.2)
    raise SystemExit("rpc failed")

def sel(sig):
    import hashlib
    # keccak via eth_hash? use cast-free tiny keccak? use sha3 library fallback
    from eth_utils import keccak
    return "0x"+keccak(text=sig)[:4].hex()

def enc_addr(a): return a[2:].rjust(64,"0")
def to_int(h): return int(h,16) if h and h!="0x" else 0

balanceOf = sel("balanceOf(address)")
getUserAccountData = sel("getUserAccountData(address)")

def fetch_accounts(addrs):
    out={}
    batch_sz=8
    for i in range(0,len(addrs),batch_sz):
        chunk=addrs[i:i+batch_sz]
        res=rpc_batch([(POOL, getUserAccountData+enc_addr(a)) for a in chunk])
        for a,h in zip(chunk,res):
            r=bytes.fromhex(h[2:]); v=[int.from_bytes(r[j*32:(j+1)*32],"big") for j in range(6)]
            out[a]={"collateral_celo":v[0]/1e18,"debt_celo":v[1]/1e18,
                    "liq_threshold_bps":v[3],"ltv_bps":v[4],"hf":v[5]/1e18}
        if i%200==0: print("acct",i,flush=True)
        time.sleep(0.02)
    return out

def fetch_balances(addrs, tokens):
    """tokens: dict name->address ; returns addr -> {name: int}"""
    out={a:{} for a in addrs}
    calls=[]; keys=[]
    for a in addrs:
        for n,t in tokens.items():
            calls.append((t, balanceOf+enc_addr(a))); keys.append((a,n))
    for i in range(0,len(calls),10):
        res=rpc_batch(calls[i:i+10])
        for (a,n),h in zip(keys[i:i+10],res):
            out[a][n]=to_int(h)
        if i%500==0: print("bal",i,flush=True)
        time.sleep(0.02)
    return out

def main():
    holders=json.load(open("/home/heisenberg/CA/moola/analysis/holders.json"))
    addrs=set()
    for tok,list_ in holders.items():
        for x in list_: addrs.add(x["addr"])
    addrs=sorted(addrs)
    print("addresses:",len(addrs))
    acct=fetch_accounts(addrs)
    liquidity=[a for a,x in acct.items() if x["hf"]<1.0 or x["debt_celo"]>0.001]
    print("accounts with debt or HF<1:",len(liquidity))
    toks={}
    for n in A: toks["a"+n]=A[n]
    for n in VD: toks["v"+n]=VD[n]
    for n in SD: toks["s"+n]=SD[n]
    bal=fetch_balances(liquidity,toks)
    # profits
    profits=[]
    for a in liquidity:
        acc=acct[a]
        if acc["hf"]>=1.0: continue
        b=bal[a]
        # collateral per token (aToken balances)
        colls={n: b.get("a"+n,0)/1e18 for n in A}
        debts={n: b.get("v"+n,0)/1e18 + b.get("s"+n,0)/1e18 for n in A}
        total_debt=sum(debts.values())
        if total_debt==0: continue
        best=0.0; bestpair=None
        for cn in A:
            if colls[cn]<=0: continue
            for dn in A:
                d=debts[dn]
                if d<=0: continue
                cprice=PRICES[cn]; dprice=PRICES[dn]
                maxrepay=d*0.5
                bonus=LIQ_BONUS[cn]; adj=bonus+RESERVE_PCT
                # collateral units seized per debt unit: (dprice * 10^cd) * adj / (cprice * 10^dd * 10000)
                maxColl = dprice*maxrepay*adj/(cprice*10000)
                if maxColl > colls[cn]:
                    seized=colls[cn]
                    debtNeeded=cprice*seized/(dprice)*10000/adj
                else:
                    seized=maxColl; debtNeeded=maxrepay
                # liquidator proceeds: seized * cprice * bonus/adj ; cost: debtNeeded*dprice
                proceeds=seized*cprice*bonus/adj
                cost=debtNeeded*dprice
                p=proceeds-cost
                if p>best: best=p; bestpair=(cn,dn,seized,debtNeeded)
        profits.append({"addr":a,"hf":acc["hf"],"profit_celo":best,"pair":bestpair,
                        "debt_celo":acc["debt_celo"],"coll_celo":acc["collateral_celo"],
                        "balances":{k:v/1e18 for k,v in b.items()}})
    profits.sort(key=lambda x:-x["profit_celo"])
    json.dump({"block":BLOCK,"account_data":acct,"profitable_liquidations":profits},
              open(f"/home/heisenberg/CA/moola/analysis/liquidations_{BLOCK}.json","w"),indent=1)
    tot=sum(p["profit_celo"] for p in profits)
    print(f"\n=== TOTAL liquidation profit estimate: {tot:.4f} CELO ===")
    for p in profits[:25]:
        print(f"  {p['addr']} HF={p['hf']:.4f} profit={p['profit_celo']:.5f} CELO pair={p['pair']} debt={p['debt_celo']:.2f} coll={p['coll_celo']:.2f}")

PRICES = {"CELO":1.0,"cUSD":11.114487445408416,"cEUR":11.811634360715485,"cREAL":2.100449195176596,"MOO":0.005}
# note: prices approximate from oracle at 79583113; used only for ranking.

if __name__=="__main__":
    from eth_utils import keccak
    main()
