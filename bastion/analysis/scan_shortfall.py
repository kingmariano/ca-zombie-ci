#!/usr/bin/env python3
"""Scan all historical borrowers for current debt and shortfall at pinned block."""
import requests, json, sys, time
from Crypto.Hash import keccak

R = "https://mainnet.aurora.dev"
BLOCK = sys.argv[1] if len(sys.argv) > 1 else "latest"
MARKETS = {
    "cETH":  "0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0",
    "cNEAR": "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
    "cUSDC": "0xe5308dc623101508952948b141fD9eaBd3337D99",
    "cUSDT": "0x845E15A441CFC1871B7AC610b0E922019BaD9826",
    "cWBTC": "0xfa786baC375D8806185555149235AcDb182C033b",
}
UNITROLLER = "0x6De54724e128274520606f038591A00C5E94a1F6"

def sel(sig):
    k=keccak.new(digest_bits=256); k.update(sig.encode()); return "0x"+k.hexdigest()[:8]
def enc_addr(a): return a[2:].lower().rjust(64,"0")

bm = json.load(open("borrowers_map.json"))
# pairs (market, borrower)
pairs = []
for mn, d in bm.items():
    for a in d["borrowers"]:
        pairs.append((mn, a))
print("pairs:", len(pairs))

SEL_BBS = sel("borrowBalanceStored(address)")
SEL_LIQ = sel("getAccountLiquidity(address)")
SEL_BAI = sel("getAssetsIn(address)")
SEL_BAL = sel("balanceOf(address)")
SEL_BS  = sel("borrowBalanceStored(address)")

sess = requests.Session()
def batch(payload):
    for i in range(6):
        try:
            r = sess.post(R, json=payload, timeout=180)
            return r.json()
        except Exception as e:
            time.sleep(2*(i+1))
    raise RuntimeError("batch failed")

def run_batch(calls):
    """calls: list of (label, to, data)"""
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data}, BLOCK]} for i,(label,to,data) in enumerate(calls)]
    res = batch(payload)
    byid = {x.get("id"): x for x in res}
    out = {}
    for i,(label,to,data) in enumerate(calls):
        x = byid.get(i, {})
        out[label] = x.get("result") if x.get("result") is not None else ("ERR:"+str(x.get("error"))[:60])
    return out

# 1) current debt per (market, borrower)
debt = {}
calls = [(f"{mn}|{a}", MARKETS[mn], SEL_BBS + enc_addr(a)) for mn,a in pairs]
CH = 40
for i in range(0, len(calls), CH):
    out = run_batch(calls[i:i+CH])
    for label, val in out.items():
        if isinstance(val, str) and not val.startswith("ERR") and int(val,16) > 0:
            mn, a = label.split("|")
            debt.setdefault(a, {})[mn] = int(val,16)
    if (i//CH) % 20 == 0:
        print(f"debt scan {i}/{len(calls)} current debtors {len(debt)}", flush=True)

print("CURRENT BORROWERS (nonzero debt):", len(debt))
json.dump(debt, open("current_debtors.json","w"), indent=1)

# 2) account liquidity for each current debtor
short = {}
liq = {}
calls = [(a, UNITROLLER, SEL_LIQ + enc_addr(a)) for a in debt]
for i in range(0, len(calls), CH):
    out = run_batch(calls[i:i+CH])
    for a, val in out.items():
        if isinstance(val, str) and val.startswith("0x") and len(val) >= 194:
            err = int(val[2:66],16); liquidity=int(val[66:130],16); shortfall=int(val[130:194],16)
            liq[a] = {"err":err,"liquidity":liquidity,"shortfall":shortfall}
            if shortfall > 0: short[a]=liq[a]
    print(f"liq scan {i}/{len(calls)} shortfall {len(short)}", flush=True)

print("SHORTFALL ACCOUNTS:", len(short))
for a,d in list(short.items())[:40]:
    print(a, "shortfallUSD", d["shortfall"]/1e18, "liqUSD", d["liquidity"]/1e18)
json.dump({"liquidity":liq,"shortfall":short}, open("account_liquidity.json","w"), indent=1)

# mark real-value status using live auri prices for reporting
print("done")
