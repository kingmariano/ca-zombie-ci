#!/usr/bin/env python3
"""Deposit sim v2: derive tick arrays, validate against known withdraw sample, run full deposit."""
import base64, hashlib, json, sys, math
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
ORCA = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
A = "/home/heisenberg/CA/armada/analysis"
r1 = json.load(open(f"{A}/recon1.json"))
r6 = json.load(open(f"{A}/recon6_lpholders.json"))
samples = json.load(open(f"{A}/ix-full-samples.json"))

def d(n):
    return hashlib.sha256(f"global:{n}".encode()).digest()[:8]

TICK_ARRAY_SIZE = 88
def tick_array_pda(whirlpool, start_tick):
    return find_pda(["tick_array", b58decode(whirlpool), str(start_tick)], ORCA)[0]
def array_start(tick, ts):
    span = ts * TICK_ARRAY_SIZE
    import math as _m
    return _m.floor(tick / span) * span

def pool_tick_spacing(whirlpool):
    a = get_account(whirlpool); raw = base64.b64decode(a["data"][0])
    return int.from_bytes(raw[41:43], "little")

def position_info(pk):
    a = get_account(pk); raw = base64.b64decode(a["data"][0])
    return {"liq": int.from_bytes(raw[72:88], "little"),
            "tl": int.from_bytes(raw[88:92], "little", signed=True),
            "tu": int.from_bytes(raw[92:96], "little", signed=True)}

# --- validate derivation on HTKMVZ withdraw sample ---
VK1 = "HTKMVZXE8HRHyBGkpXGwzRgncy5HxAoo9Ls21ouzqNoL"
v1 = r1["vaults"][VK1]
ts = pool_tick_spacing(v1["clp"])
rem_sample = samples["withdraw"][0]["accounts"][16:]
print("HTKMVZ tickSpacing:", ts)
derived = []
for p in v1["positions"]:
    pk = p["position_key"]
    if pk == "11111111111111111111111111111111":
        continue
    pi = position_info(pk)
    lo = array_start(pi["tl"], ts)
    hi = array_start(pi["tu"], ts)
    derived += [pk, tick_array_pda(v1["clp"], lo), tick_array_pda(v1["clp"], hi)]
print("derived matches sample:", derived == rem_sample)
if derived != rem_sample:
    for i, (x, y) in enumerate(zip(derived, rem_sample)):
        print(i, x[:12], y[:12], "OK" if x == y else "<<<")

# --- deposit for DRgwP2sZ ---
VK = "DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq"
v = r1["vaults"][VK]
dep = "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU"
cand = [c for c in json.load(open(f"{A}/depositor-candidates.json")) if c[0] == VK and c[1] == dep][0]
_, owner, lp_bal, ata_a_amt, ata_b_amt, ata_a, ata_b = cand
lp_ata = [h["ata"] for h in r6[VK]["top"] if h["owner"] == dep][0]
w = get_account(v["clp"]); wraw = base64.b64decode(w["data"][0])
clp_ta = b58encode(wraw[133:165]); clp_tb = b58encode(wraw[213:245])
ts2 = pool_tick_spacing(v["clp"])
remaining = []
for p in v["positions"]:
    pk = p["position_key"]
    if pk == "11111111111111111111111111111111":
        continue
    pi = position_info(pk)
    lo = array_start(pi["tl"], ts2)
    hi = array_start(pi["tu"], ts2)
    remaining += [pk, tick_array_pda(v["clp"], lo), tick_array_pda(v["clp"], hi)]
print("DRgwP2sZ remaining accounts:", len(remaining))

MAX = (1 << 64) - 1
LP_MINT_AMOUNT = 1_000_000  # 1.0 LP (6 decimals)

def build_deposit(amount, remaining, user_a, user_b, lp_acct):
    accounts = [
        (dep, True, False), (user_a, False, True), (user_b, False, True), (lp_acct, False, True),
        (VK, False, False), (v["lp_mint"], False, True), (v["token_vault_a"], False, True),
        (v["token_vault_b"], False, True), (v["position_bundle_token_account"], False, False),
        (ORCA, False, False), (v["clp"], False, True), (clp_ta, False, True), (clp_tb, False, True),
        (TOKEN, False, False),
    ]
    accounts += [(p, False, True) for p in remaining]
    data = d("deposit") + amount.to_bytes(8, "little") + MAX.to_bytes(8, "little") + MAX.to_bytes(8, "little")
    return {"program_id": PROG, "accounts": accounts, "data": data}

ret = [ata_a, ata_b, lp_ata, v["lp_mint"], v["token_vault_a"], v["token_vault_b"], VK]
res = simulate([build_deposit(LP_MINT_AMOUNT, remaining, ata_a, ata_b, lp_ata)], dep, return_accounts=ret)
s = summarize(res)
print("\n===== deposit 1.0 LP with derived remaining =====")
print("err:", s["err"], "CU:", s.get("unitsConsumed"))
for l in s["logs_tail"][:26]:
    print("   ", l)
print("--- post accounts ---")
for a in (res.get("value") or {}).get("accounts") or []:
    if not a:
        print("  (missing)")
        continue
    raw = base64.b64decode(a["data"][0]); pk = a.get("pubkey")
    amt = int.from_bytes(raw[64:72], "little") if len(raw) > 72 else int.from_bytes(raw[36:44], "little")
    print(" ", pk[:14], "->", amt)
print("pre balances: A", ata_a_amt, "B", ata_b_amt, "LP", lp_bal)
