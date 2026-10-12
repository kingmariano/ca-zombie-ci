#!/usr/bin/env python3
"""Measure withdraw payout vs live-fair share (HTKMVZ, self-withdraw by top holder)."""
import base64, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
A = "/home/heisenberg/CA/armada/analysis"
s = json.load(open(f"{A}/ix-full-samples.json"))
w = s["withdraw"][0]
base = list(w["accounts"])
data = b58decode(w["data"])
lp_amount = int.from_bytes(data[8:16], "little")
data0 = data[:8] + data[8:16] + (0).to_bytes(8, "little") + (0).to_bytes(8, "little")
r1 = json.load(open(f"{A}/recon1.json")); r2 = json.load(open(f"{A}/recon2.json")); r6 = json.load(open(f"{A}/recon6_lpholders.json"))
val = json.load(open(f"{A}/valuation3.json"))
VK = base[4]; v = r1["vaults"][VK]
cur = r6[VK]["top"][0]

def token_amount(pk):
    a = get_account(pk, encoding="jsonParsed")
    try:
        info = a["data"]["parsed"]["info"]
        if "tokenAmount" in info:
            return int(info["tokenAmount"]["amount"])
        return int(info["supply"])
    except Exception:
        return None

atas = {}
for mint, tag in ((v["token_mint_a"], "a"), (v["token_mint_b"], "b")):
    r = rpc("getTokenAccountsByOwner", [cur["owner"], {"mint": mint}, {"encoding": "jsonParsed"}])
    vals = (r or {}).get("value") or []
    atas[tag] = vals[0]["pubkey"] if vals else None

accts = list(base)
accts[0] = cur["owner"]; accts[3] = cur["ata"]; accts[1] = atas["a"]; accts[2] = atas["b"]
ro = {4, 8, 9, 15}
metas = [(a, i == 0, i not in ro) for i, a in enumerate(accts)]
ret = [accts[3], accts[1], accts[2], accts[5], accts[6], accts[7]]
pre = {"lp": token_amount(accts[3]), "a": token_amount(accts[1]), "b": token_amount(accts[2]),
       "tvA": token_amount(accts[6]), "tvB": token_amount(accts[7]), "supply": token_amount(accts[5])}
print("withdrawing LP:", lp_amount, "of holder balance", pre["lp"])
res = simulate([{"program_id": PROG, "accounts": metas, "data": data0}], cur["owner"], return_accounts=ret)
summ = summarize(res)
print("err:", summ["err"], "CU:", summ.get("unitsConsumed"))
post = {}
for addr, a in zip(ret, (res.get("value") or {}).get("accounts") or []):
    if not a: continue
    raw = base64.b64decode(a["data"][0])
    if addr == accts[5]:
        post[addr] = int.from_bytes(raw[36:44], "little")
    else:
        post[addr] = int.from_bytes(raw[64:72], "little")
dv = val["vaults"][VK]
live_a = dv["bal_a"] + dv["pos_amt_a"]; live_b = dv["bal_b"] + dv["pos_amt_b"]
supply = pre["supply"]
fair_a = lp_amount * live_a // supply; fair_b = lp_amount * live_b // supply
got_a = post.get(accts[1], 0) - pre["a"]; got_b = post.get(accts[2], 0) - pre["b"]
lp_burned = pre["lp"] - post.get(accts[3], pre["lp"])
print(f"LP burned: {lp_burned}")
print(f"received A: {got_a} (live-fair {fair_a}, ratio {got_a/max(fair_a,1):.4f})")
print(f"received B: {got_b} (live-fair {fair_b}, ratio {got_b/max(fair_b,1):.4f})")
print("staging A change:", post.get(accts[6], 0) - pre["tvA"], " staging B change:", post.get(accts[7], 0) - pre["tvB"])
print("lp supply change:", post.get(accts[5], 0) - supply)
json.dump({"lp_burned": lp_burned, "got_a": got_a, "got_b": got_b, "fair_a": fair_a, "fair_b": fair_b,
           "pre": pre, "post": {k: v2 for k, v2 in post.items()}},
          open(f"{A}/withdraw-fairness.json", "w"), indent=1)
