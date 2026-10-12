#!/usr/bin/env python3
"""Round-trip test: deposit LP then immediately withdraw same LP; measure token P/L.
   If tokens_out > tokens_in, an unprivileged arbitrage exists."""
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

d = lambda n: hashlib.sha256(f"global:{n}".encode()).digest()[:8]
TICK_ARRAY_SIZE = 88
def tick_array_pda(whirlpool, start_tick):
    return find_pda(["tick_array", b58decode(whirlpool), str(start_tick)], ORCA)[0]
def array_start(tick, ts):
    return math.floor(tick / (ts * TICK_ARRAY_SIZE)) * (ts * TICK_ARRAY_SIZE)
def pool_ts(whirlpool):
    raw = base64.b64decode(get_account(whirlpool)["data"][0]); return int.from_bytes(raw[41:43], "little")
def position_info(pk):
    raw = base64.b64decode(get_account(pk)["data"][0])
    return (int.from_bytes(raw[72:88], "little"), int.from_bytes(raw[88:92], "little", signed=True),
            int.from_bytes(raw[92:96], "little", signed=True))
def token_amount(pk):
    a = get_account(pk, encoding="jsonParsed")
    try:
        info = a["data"]["parsed"]["info"]
        return int(info["tokenAmount"]["amount"]) if "tokenAmount" in info else int(info["supply"])
    except Exception:
        return None
def ata_of(owner, mint):
    r = rpc("getTokenAccountsByOwner", [owner, {"mint": mint}, {"encoding": "jsonParsed"}])
    vals = (r or {}).get("value") or []
    return vals[0]["pubkey"] if vals else None

def roundtrip(VK, depositor, lp_raw, tag):
    v = r1["vaults"][VK]
    lp_ata = [h["ata"] for h in r6[VK]["top"] if h["owner"] == depositor][0]
    ata_a = ata_of(depositor, v["token_mint_a"]); ata_b = ata_of(depositor, v["token_mint_b"])
    fee_a = ata_of(v["fee_owner"], v["token_mint_a"]); fee_b = ata_of(v["fee_owner"], v["token_mint_b"])
    wraw = base64.b64decode(get_account(v["clp"])["data"][0])
    clp_ta = b58encode(wraw[133:165]); clp_tb = b58encode(wraw[213:245])
    ts = pool_ts(v["clp"])
    remaining = []
    for p in v["positions"]:
        pk = p["position_key"]
        if pk == "11111111111111111111111111111111": continue
        _, tl, tu = position_info(pk)
        remaining += [pk, tick_array_pda(v["clp"], array_start(tl, ts)), tick_array_pda(v["clp"], array_start(tu, ts))]
    MAX = (1 << 64) - 1
    dep_ix = {"program_id": PROG, "accounts": [
        (depositor, True, False), (ata_a, False, True), (ata_b, False, True), (lp_ata, False, True),
        (VK, False, False), (v["lp_mint"], False, True), (v["token_vault_a"], False, True),
        (v["token_vault_b"], False, True), (v["position_bundle_token_account"], False, False),
        (ORCA, False, False), (v["clp"], False, True), (clp_ta, False, True), (clp_tb, False, True),
        (TOKEN, False, False)] + [(p, False, True) for p in remaining],
        "data": d("deposit") + lp_raw.to_bytes(8, "little") + MAX.to_bytes(8, "little") + MAX.to_bytes(8, "little")}
    wd_ix = {"program_id": PROG, "accounts": [
        (depositor, True, False), (ata_a, False, True), (ata_b, False, True), (lp_ata, False, True),
        (VK, False, False), (v["lp_mint"], False, True), (v["token_vault_a"], False, True),
        (v["token_vault_b"], False, True), (v["position_bundle_token_account"], False, False),
        (ORCA, False, False), (v["clp"], False, True), (clp_ta, False, True), (clp_tb, False, True),
        (fee_a or depositor, False, True), (fee_b or depositor, False, True), (TOKEN, False, False)]
        + [(p, False, True) for p in remaining],
        "data": d("withdraw") + lp_raw.to_bytes(8, "little") + (0).to_bytes(8, "little") + (0).to_bytes(8, "little")}
    pre = {"a": token_amount(ata_a), "b": token_amount(ata_b), "lp": token_amount(lp_ata)}
    ret = [ata_a, ata_b, lp_ata]
    res = simulate([dep_ix, wd_ix], depositor, return_accounts=ret)
    summ = summarize(res)
    post = {}
    for addr, a in zip(ret, (res.get("value") or {}).get("accounts") or []):
        if not a: continue
        post[addr] = int.from_bytes(base64.b64decode(a["data"][0])[64:72], "little")
    print(f"\n===== roundtrip {tag}: deposit+withdraw {lp_raw} raw LP =====")
    print("err:", summ["err"], "CU:", summ.get("unitsConsumed"))
    for l in summ["logs_tail"][-6:]:
        print("   ", l)
    da = post.get(ata_a, pre["a"]) - pre["a"]; db = post.get(ata_b, pre["b"]) - pre["b"]
    dlp = post.get(lp_ata, pre["lp"]) - pre["lp"]
    print(f"delta A: {da}   delta B: {db}   delta LP: {dlp}")
    print("=> net " + ("PROFIT" if (da > 0 or db > 0) else "LOSS/neutral"))
    return {"da": da, "db": db, "dlp": dlp, "err": summ["err"]}

out = {}
out["DRgw-1LP"] = roundtrip("DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq", "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU", 1_000_000, "DRgwP2sZ 1.0 LP")
out["DRgw-100LP"] = roundtrip("DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq", "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU", 100_000_000, "DRgwP2sZ 100 LP")
out["DRgw-1raw"] = roundtrip("DRgwP2sZ22c2bmpKSatgemMX7XmgFMWTPm8xAhrwUCTq", "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU", 1, "DRgwP2sZ 1 raw LP (rounding)")
json.dump(out, open(f"{A}/roundtrip.json", "w"), indent=1)
