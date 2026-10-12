#!/usr/bin/env python3
"""Sim 1: setVaultRatioCache — permissionless? wrong-account gates?"""
import hashlib, json, sys, base64
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
ORCA = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
A = "/home/heisenberg/CA/armada/analysis"
r1 = json.load(open(f"{A}/recon1.json"))

def d(name):
    return hashlib.sha256(f"global:{name}".encode()).digest()[:8]

vault = r1["vaults"]["6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"]
payer = "9HArgPaKd1sBPBSPQvWXqEEc9KbPU5MAAhUp1Y2nJPwZ"  # a repeat LP holder (unprivileged)
# note: exact payer pubkey resolved below from lp holder data if needed

# find a neutral existing payer: use the LP holder from recon6
lh = json.load(open(f"{A}/recon6_lpholders.json"))
payer = lh["7c75jrcMMJVEPtr1hwdBQTMJCKpjquGQk9b3p237vYyc"]["top"][0]["owner"]
print("payer (unprivileged LP holder):", payer)
print("payer account:", json.dumps(get_account(payer))[:200])

def sim_ratio_cache(va, vb, clp, lp_mint, label):
    data = d("set_vault_ratio_cache")
    accounts = [
        (vault_key, False, True),        # clpVault (mut)
        (va, False, False),              # tokenVaultA
        (vb, False, False),              # tokenVaultB
        (ORCA, False, False),            # clpProgram
        (clp, False, True),              # clp (mut)
        (lp_mint, False, True),          # lpMint (mut)
    ]
    ix = {"program_id": PROG, "accounts": accounts, "data": data}
    res = simulate([ix], payer)
    s = summarize(res)
    print(f"\n--- {label} ---")
    print("err:", s["err"], "CU:", s.get("unitsConsumed"))
    for l in s["logs_tail"][:25]:
        print("   ", l)
    return res

vault_key = "6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"
# happy path (all correct accounts)
sim_ratio_cache(vault["token_vault_a"], vault["token_vault_b"], vault["clp"], vault["lp_mint"], "correct accounts")

# wrong token vault A (use another vault's)
other = r1["vaults"]["DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq"]["token_vault_a"]
sim_ratio_cache(other, vault["token_vault_b"], vault["clp"], vault["lp_mint"], "wrong tokenVaultA")

# wrong clp (use another vault's whirlpool)
other_clp = r1["vaults"]["DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq"]["clp"]
sim_ratio_cache(vault["token_vault_a"], vault["token_vault_b"], other_clp, vault["lp_mint"], "wrong clp")

# wrong lp mint
other_lp = r1["vaults"]["DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq"]["lp_mint"]
sim_ratio_cache(vault["token_vault_a"], vault["token_vault_b"], vault["clp"], other_lp, "wrong lpMint")
