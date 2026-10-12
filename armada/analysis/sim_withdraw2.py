#!/usr/bin/env python3
"""Withdraw simulations v2: proper signer handling; self-withdraw + attack variants."""
import base64, hashlib, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
A = "/home/heisenberg/CA/armada/analysis"
s = json.load(open(f"{A}/ix-full-samples.json"))
w = s["withdraw"][0]
base_accts = w["accounts"]
data = b58decode(w["data"])
lp_amount = int.from_bytes(data[8:16], "little")
vault = base_accts[4]
r1 = json.load(open(f"{A}/recon1.json"))
v = r1["vaults"][vault]
r6 = json.load(open(f"{A}/recon6_lpholders.json"))
holders = r6[vault]["top"]
print("vault", vault[:12], "lpAmount", lp_amount, "holders:", [(h["owner"][:10], h["amount"]) for h in holders[:3]])

def build_metas(accts, signer_idx=0, ro_idx=(4, 8, 9, 15)):
    return [(a, i == signer_idx, i not in ro_idx) for i, a in enumerate(accts)]

def run(label, payer, accts, ix_data, return_accounts=None):
    metas = build_metas(accts)
    ix = {"program_id": PROG, "accounts": metas, "data": ix_data}
    res = simulate([ix], payer, return_accounts=return_accounts)
    summ = summarize(res)
    print(f"\n===== {label} =====")
    print("err:", summ["err"], "CU:", summ.get("unitsConsumed"))
    for l in summ["logs_tail"][:22]:
        print("   ", l)
    return res, summ

# find ATAs of the current top holder for the vault's mints
cur = holders[0]
print("\ncurrent top holder:", cur["owner"], "LP:", cur["amount"], "ata:", cur["ata"])
ata_a = ata_b = None
for mint, tag in ((v["token_mint_a"], "a"), (v["token_mint_b"], "b")):
    try:
        r = rpc("getTokenAccountsByOwner", [cur["owner"], {"mint": mint}, {"encoding": "jsonParsed"}])
        vals = (r or {}).get("value") or []
        if vals:
            info = vals[0]["account"]["data"]["parsed"]["info"]
            print(f"  holder ATA {tag}: {vals[0]['pubkey']} amount {info['tokenAmount']['amount']}")
            if tag == "a": ata_a = vals[0]["pubkey"]
            else: ata_b = vals[0]["pubkey"]
    except Exception as e:
        print("  ata lookup fail", tag, redact(e)[:80])

# --- Variant 1: owner mismatch — payer = current holder, LP account = another holder's ---
other = holders[1] if len(holders) > 1 else holders[0]
accts1 = list(base_accts)
accts1[0] = cur["owner"]              # signer
accts1[3] = other["ata"]              # LP account of a DIFFERENT holder
accts1[1] = ata_a or base_accts[1]
accts1[2] = ata_b or base_accts[2]
run("1. payer=holderA, userLpTokenAcct=holderB's LP (owner mismatch)", cur["owner"], accts1, data)

# --- Variant 2: self-withdraw by holderA (fair value) ---
accts2 = list(base_accts)
accts2[0] = cur["owner"]
accts2[3] = cur["ata"]
accts2[1] = ata_a or base_accts[1]
accts2[2] = ata_b or base_accts[2]
ret = [accts2[3], accts2[1], accts2[2], accts2[5], accts2[6], accts2[7], accts2[4]]
res2, summ2 = run("2. self-withdraw holderA (LP " + str(lp_amount) + ")", cur["owner"], accts2, data, return_accounts=ret)

# --- Variant 3: attacker with no LP: payer = MM key, LP acct = holderA's (mismatch) ---
attacker = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"
accts3 = list(base_accts)
accts3[0] = attacker
accts3[3] = cur["ata"]
accts3[1] = ata_a or base_accts[1]
accts3[2] = ata_b or base_accts[2]
run("3. attacker payer, holderA LP acct", attacker, accts3, data)

# --- Variant 4: wrong lp mint ---
accts4 = list(accts2)
accts4[5] = r1["vaults"]["6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"]["lp_mint"]
run("4. wrong lpMint", cur["owner"], accts4, data)

# --- Variant 5: wrong token vault B ---
accts5 = list(accts2)
accts5[7] = r1["vaults"]["6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"]["token_vault_b"]
run("5. wrong tokenVaultB", cur["owner"], accts5, data)

# --- Variant 6: withdraw 0 LP ---
data0 = data[:8] + (0).to_bytes(8, "little") + data[16:]
run("6. lpAmount=0 self-withdraw", cur["owner"], accts2, data0)

# post-account decode for variant 2
if res2:
    print("\n--- variant 2 post accounts ---")
    for a in (res2.get("value") or {}).get("accounts") or []:
        if not a: continue
        raw = base64.b64decode(a["data"][0])
        pk = a.get("pubkey")
        if pk == accts2[3]:
            print("lp acct post amount:", int.from_bytes(raw[64:72], "little"))
        elif pk in (accts2[1], accts2[2]):
            print("user token acct", pk[:8], "post amount:", int.from_bytes(raw[64:72], "little"))
        elif pk == accts2[5]:
            print("lpMint post supply:", int.from_bytes(raw[36:44], "little"))
        elif pk == accts2[6]:
            print("tokenVaultA post:", int.from_bytes(raw[64:72], "little"))
        elif pk == accts2[7]:
            print("tokenVaultB post:", int.from_bytes(raw[64:72], "little"))
