#!/usr/bin/env python3
"""Deposit fair-value measurement: exact tokens pulled vs LP minted."""
import base64, hashlib, json, math, sys
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
val = json.load(open(f"{A}/valuation3.json"))

d = lambda n: hashlib.sha256(f"global:{n}".encode()).digest()[:8]
TICK_ARRAY_SIZE = 88
def tick_array_pda(whirlpool, start_tick):
    return find_pda(["tick_array", b58decode(whirlpool), str(start_tick)], ORCA)[0]
def array_start(tick, ts):
    span = ts * TICK_ARRAY_SIZE
    return math.floor(tick / span) * span
def pool_tick_spacing(whirlpool):
    a = get_account(whirlpool); raw = base64.b64decode(a["data"][0])
    return int.from_bytes(raw[41:43], "little")
def position_info(pk):
    a = get_account(pk); raw = base64.b64decode(a["data"][0])
    return {"liq": int.from_bytes(raw[72:88], "little"),
            "tl": int.from_bytes(raw[88:92], "little", signed=True),
            "tu": int.from_bytes(raw[92:96], "little", signed=True)}

def token_amount(pk):
    a = get_account(pk, encoding="jsonParsed")
    if not a: return None
    try:
        return int(a["data"]["parsed"]["info"]["tokenAmount"]["amount"])
    except Exception:
        return None

def run_deposit(VK, depositor, lp_amount_raw, tag):
    v = r1["vaults"][VK]
    cand = [c for c in json.load(open(f"{A}/depositor-candidates.json")) if c[0] == VK and c[1] == depositor]
    if not cand:
        print("no candidate"); return
    _, owner, lp_bal, _, _, ata_a, ata_b = cand[0]
    lp_ata = [h["ata"] for h in r6[VK]["top"] if h["owner"] == depositor][0]
    w = get_account(v["clp"]); wraw = base64.b64decode(w["data"][0])
    clp_ta = b58encode(wraw[133:165]); clp_tb = b58encode(wraw[213:245])
    ts = pool_tick_spacing(v["clp"])
    remaining = []
    for p in v["positions"]:
        pk = p["position_key"]
        if pk == "11111111111111111111111111111111": continue
        pi = position_info(pk)
        remaining += [pk, tick_array_pda(v["clp"], array_start(pi["tl"], ts)), tick_array_pda(v["clp"], array_start(pi["tu"], ts))]
    MAX = (1 << 64) - 1
    accounts = [
        (depositor, True, False), (ata_a, False, True), (ata_b, False, True), (lp_ata, False, True),
        (VK, False, False), (v["lp_mint"], False, True), (v["token_vault_a"], False, True),
        (v["token_vault_b"], False, True), (v["position_bundle_token_account"], False, False),
        (ORCA, False, False), (v["clp"], False, True), (clp_ta, False, True), (clp_tb, False, True),
        (TOKEN, False, False)] + [(p, False, True) for p in remaining]
    data = d("deposit") + lp_amount_raw.to_bytes(8, "little") + MAX.to_bytes(8, "little") + MAX.to_bytes(8, "little")
    ix = {"program_id": PROG, "accounts": accounts, "data": data}
    pre = {"a": token_amount(ata_a), "b": token_amount(ata_b), "lp": token_amount(lp_ata)}
    ret_addrs = [ata_a, ata_b, lp_ata]
    res = simulate([ix], depositor, return_accounts=ret_addrs)
    summ = summarize(res)
    print(f"\n===== {tag} =====")
    print("err:", summ["err"], "CU:", summ.get("unitsConsumed"))
    post = {}
    for addr, a in zip(ret_addrs, (res.get("value") or {}).get("accounts") or []):
        if not a: continue
        raw = base64.b64decode(a["data"][0])
        post[addr] = int.from_bytes(raw[64:72], "little")
    dv = val["vaults"][VK]
    live_a = dv["bal_a"] + dv["pos_amt_a"]; live_b = dv["bal_b"] + dv["pos_amt_b"]
    supply = int(r2["lp_supply"][v["lp_mint"]]["amount"])
    fair_a = lp_amount_raw * live_a // supply
    fair_b = lp_amount_raw * live_b // supply
    print("pre :", pre)
    print("post:", {k[:10]: v2 for k, v2 in post.items()})
    da = pre["a"] - post.get(ata_a, 0); db = pre["b"] - post.get(ata_b, 0); dlp = post.get(lp_ata, 0) - pre["lp"]
    print(f"pulled A: {da} (fair {fair_a}, ratio {da/max(fair_a,1):.6f})")
    print(f"pulled B: {db} (fair {fair_b}, ratio {db/max(fair_b,1):.6f})")
    print(f"LP minted: {dlp} (requested {lp_amount_raw})")
    return {"da": da, "db": db, "fair_a": fair_a, "fair_b": fair_b, "dlp": dlp}

r1out = run_deposit("DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq", "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU", 1_000_000, "DRgwP2sZ USDC/JitoSOL, 1.0 LP")
json.dump(r1out, open(f"{A}/deposit-fairness.json", "w"), indent=1)
