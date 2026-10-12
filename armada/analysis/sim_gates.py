#!/usr/bin/env python3
"""Gate tests: collectFees/collectRewards destination checks, externalSwap signer, updateConfig admin."""
import base64, hashlib, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
A = "/home/heisenberg/CA/armada/analysis"
samples = json.load(open(f"{A}/ix-full-samples.json"))
r1 = json.load(open(f"{A}/recon1.json"))
d = lambda n: hashlib.sha256(f"global:{n}".encode()).digest()[:8]
ATT = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"  # MM key; use as generic unprivileged signer

def sim(label, payer, accounts, data, ret=None):
    ix = {"program_id": PROG, "accounts": accounts, "data": data}
    res = simulate([ix], payer, return_accounts=ret)
    summ = summarize(res)
    print(f"\n===== {label} ===== err={summ['err']} CU={summ.get('unitsConsumed')}")
    for l in summ["logs_tail"][-12:]:
        print("   ", l)
    return res, summ

# ---------- collect_fees ----------
cf = samples["collect_fees"][0]
print("collect_fees sample sig:", cf["sig"][:20], "n_acc", len(cf["accounts"]), "vault", cf["accounts"][1][:12])
acc = cf["accounts"]
# replay: figure out signer = account 0
metas = [(a, i == 0, True) for i, a in enumerate(acc)]
metas = [(a, i == 0, not (i in (2, 3))) for i, a in enumerate(acc)]  # clpProgram/clp readonly? keep simple: all mut except program
res, _ = sim("collect_fees replay (real accounts, signer=hist payer)", acc[0], metas, b58decode(cf["data"]))

# attack: replace fee accounts (10,11) and mm fee accounts (12,13) with attacker-owned token accounts
# find attacker ATAs for the vault's mints
vault = acc[1]
v = r1["vaults"].get(vault)
print("vault found:", bool(v), vault[:12])
if v:
    def ata_of(owner, mint):
        r = rpc("getTokenAccountsByOwner", [owner, {"mint": mint}, {"encoding": "jsonParsed"}])
        vals = (r or {}).get("value") or []
        return vals[0]["pubkey"] if vals else None
    att_a = ata_of(ATT, v["token_mint_a"]); att_b = ata_of(ATT, v["token_mint_b"])
    print("attacker ATAs:", att_a, att_b)
    acc2 = list(acc)
    if att_a: acc2[10] = att_a
    if att_b: acc2[11] = att_b
    metas2 = [(a, i == 0, not (i in (2, 3))) for i, a in enumerate(acc2)]
    sim("collect_fees ATTACK: fee accounts = attacker ATAs", acc[0], metas2, b58decode(cf["data"]))

# ---------- collect_rewards ----------
cr = samples["collect_rewards"][0]
accr = cr["accounts"]
print("\ncollect_rewards sample sig:", cr["sig"][:20], "n_acc", len(accr))
metasr = [(a, i == 0, True) for i, a in enumerate(accr)]
sim("collect_rewards replay (real accounts)", accr[0], metasr, b58decode(cr["data"]))

# ---------- external_swap_setup without MM signer ----------
es = samples["external_swap_setup"][0]
acce = es["accounts"]
print("\nexternal_swap_setup sample sig:", es["sig"][:20], "n_acc", len(acce))
print("  accounts:", [a[:12] for a in acce])
metase = [(a, i == 0, i in (1, 2)) for i, a in enumerate(acce)]  # MM is account0 signer in real ix
sim("external_swap_setup replay (MM as signer)", acce[0], metase, b58decode(es["data"]))
# attack: signer = attacker, MM account passed but not signing
metase2 = [(a, i == 0, i in (1, 2)) for i, a in enumerate(acce)]
metase2[0] = (ATT, True, False)  # attacker signs; MM account (index?) not signed
sim("external_swap_setup ATTACK: attacker signer, MM not signing", ATT, metase2, b58decode(es["data"]))

# ---------- update_config without admin ----------
v2 = r1["vaults"]["6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"]
# args: marketMakingKey(32) feeOwner(32) performanceFee u32 withdrawalFee u32 marketMakingFee u32 strategy u8 stakePool(32) featuresEnabled u8
args = b58decode(v2["market_making_key"]) + b58decode(v2["fee_owner"]) + (408021893).to_bytes(4, "little") + (0).to_bytes(4, "little") + (408021893).to_bytes(4, "little") + bytes([1]) + b58decode(v2["stake_pool"]) + bytes([1])
data_uc = d("update_config") + args
accounts = [(ATT, True, True), ("6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK", False, True)]
sim("update_config ATTACK: attacker signer (not admin)", ATT, accounts, data_uc)
# privileged variant for comparison: admin as signer (7btJUB) — read-only sim, no state change
accounts_admin = [("7btJUBpZq3pzhYJBF9pkCBJ4xa4de1ZnUeJ4WiA5TiHT", True, True), ("6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK", False, True)]
sim("update_config with admin key as signer (privileged)", "7btJUBpZq3pzhYJBF9pkCBJ4xa4de1ZnUeJ4WiA5TiHT", accounts_admin, data_uc)

# ---------- update_token_meta with attacker ----------
utm = samples.get("update_token_meta", [])
print("\nupdate_token_meta samples:", len(utm))
