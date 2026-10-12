#!/usr/bin/env python3
"""Deposit simulation: fair-value check + remaining-account discovery."""
import base64, hashlib, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
ORCA = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
A = "/home/heisenberg/CA/armada/analysis"
r1 = json.load(open(f"{A}/recon1.json"))
r6 = json.load(open(f"{A}/recon6_lpholders.json"))
r2 = json.load(open(f"{A}/recon2.json"))

def d(n):
    return hashlib.sha256(f"global:{n}".encode()).digest()[:8]

VK = "DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq"
v = r1["vaults"][VK]
dep = "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU"
cand = [c for c in json.load(open(f"{A}/depositor-candidates.json")) if c[0] == VK and c[1] == dep][0]
_, owner, lp_bal, ata_a_amt, ata_b_amt, ata_a, ata_b = cand
# find LP ATA of depositor for this vault
lp_ata = None
for h in r6[VK]["top"]:
    if h["owner"] == dep:
        lp_ata = h["ata"]
print("vault:", VK, "depositor:", dep, "lp_ata:", lp_ata, "lp_bal:", lp_bal)
print("ata_a:", ata_a, "bal", ata_a_amt, " ata_b:", ata_b, "bal", ata_b_amt)

lp_mint = v["lp_mint"]
lp_dec = 6
try:
    mintinfo = spl_mint_parsed(lp_mint)
    lp_dec = mintinfo["decimals"]
except Exception:
    pass
print("lp mint:", lp_mint, "decimals:", lp_dec)

LP_MINT_AMOUNT = 1_000_000  # raw; adjust by decimals below
MAX = (1 << 64) - 1

def build_deposit(remaining):
    accounts = [
        (dep, True, False),           # payer (signer, ro)
        (ata_a, False, True),         # userTokenA
        (ata_b, False, True),         # userTokenB
        (lp_ata, False, True),        # userLpTokenAcct
        (VK, False, False),           # clpVault
        (lp_mint, False, True),       # lpMint
        (v["token_vault_a"], False, True),
        (v["token_vault_b"], False, True),
        (v["position_bundle_token_account"], False, False),
        (ORCA, False, False),         # clpProgram
        (v["clp"], False, True),      # clp
        (None, False, True),          # clpTokenVaultA (filled below)
        (None, False, True),          # clpTokenVaultB
        (TOKEN, False, False),        # tokenProgram
    ]
    # clp token vaults from the whirlpool account
    w = get_account(v["clp"]); raw = base64.b64decode(w["data"][0])
    accounts[11] = (b58encode(raw[133:165]), False, True)
    accounts[12] = (b58encode(raw[213:245]), False, True)
    accounts += [(p, False, True) for p in remaining]
    data = d("deposit") + LP_MINT_AMOUNT.to_bytes(8, "little") + MAX.to_bytes(8, "little") + MAX.to_bytes(8, "little")
    return {"program_id": PROG, "accounts": accounts, "data": data}

ret = [ata_a, ata_b, lp_ata, lp_mint, v["token_vault_a"], v["token_vault_b"]]
res = simulate([build_deposit([])], dep, return_accounts=ret)
s = summarize(res)
print("\n===== deposit, no remaining accounts =====")
print("err:", s["err"], "CU:", s.get("unitsConsumed"))
for l in s["logs_tail"][:20]:
    print("   ", l)

def decode_post(res):
    print("--- post accounts ---")
    for a in (res.get("value") or {}).get("accounts") or []:
        if not a:
            print("  (missing account)")
            continue
        raw = base64.b64decode(a["data"][0])
        pk = a.get("pubkey")
        amt = int.from_bytes(raw[64:72], "little") if len(raw) > 72 else int.from_bytes(raw[36:44], "little")
        print(" ", pk[:12], "->", amt)
    inner = (res.get("value") or {}).get("innerInstructions") or []
    print("inner ix groups:", len(inner))
    for g in inner:
        for ix in g.get("instructions") or []:
            pid = ix.get("programId") or ix.get("programIdIndex")
            print("   inner:", pid, (ix.get("data") or "")[:20])

decode_post(res)
