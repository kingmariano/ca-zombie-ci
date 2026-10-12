#!/usr/bin/env python3
"""CI verification job for the Armada CLP-vault deep-dive (read-only).

Reproduces:
  1. program meta (upgrade authority, programdata)
  2. ClpVault enumeration (24) + staging balances
  3. live simulations of the key gate tests:
       - self-withdraw by LP holder        -> expect SUCCESS (H-O live)
       - attacker withdraws victim's LP    -> expect SPL 'owner does not match' (blocked)
       - collectFees fee-account substitution -> expect IncorrectFeeOwner (6019)
       - externalSwapSetup w/o MM signer   -> expect AccountNotSigner (3010)
       - updateConfig w/o admin            -> expect InccorrectAdminKey (6018)
Outputs ci-out/verify.json (+ readable log on stdout). No keys are ever printed.
"""
import base64, hashlib, json, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "analysis"))
from solrpc import (rpc, get_account, get_accounts, get_program_accounts, programdata_address,
                    b58decode, b58encode, disc, redact, spl_token_amount, find_pda)
from simtx import simulate, summarize

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
ORCA = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
A = os.path.join(HERE, "..", "analysis")
OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

result = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "steps": {}}

def log(*a):
    print(*a, flush=True)

# ---------- 1. program meta ----------
try:
    a = get_account(PROG)
    pd = programdata_address(PROG)
    praw = base64.b64decode(get_account(pd)["data"][0])
    slot = int.from_bytes(praw[4:12], "little")
    has_auth = praw[12]
    auth = b58encode(praw[13:45]) if has_auth else None
    ua = get_account(auth) if auth else None
    result["steps"]["program"] = {"program_id": PROG, "owner": a["owner"], "executable": a["executable"],
                                  "programdata": pd, "deployed_slot": slot, "upgrade_authority": auth,
                                  "upgrade_authority_owner": ua["owner"] if ua else None,
                                  "upgrade_authority_lamports": ua["lamports"] if ua else None}
    log("program:", json.dumps(result["steps"]["program"]))
except Exception as e:
    result["steps"]["program"] = {"error": redact(e)}
    log("program meta FAILED:", redact(e))

# ---------- 2. ClpVault enumeration + balances ----------
try:
    accs = get_program_accounts(PROG, filters=[{"memcmp": {"offset": 0, "bytes": b58encode(disc("account:ClpVault"))}}],
                                encoding="base64", timeout=180)
    vaults = []
    for acc in accs:
        raw = base64.b64decode(acc["account"]["data"][0])
        b = raw[8:]
        v = {"key": acc["pubkey"],
             "clp": b58encode(b[32:64]), "lp_mint": b58encode(b[64:96]),
             "mint_a": b58encode(b[112:144]), "vault_a": b58encode(b[144:176]),
             "mint_b": b58encode(b[176:208]), "vault_b": b58encode(b[208:240]),
             "admin": b58encode(b[336:368]), "mm": b58encode(b[304:336]), "fee_owner": b58encode(b[368:400]),
             "withdrawal_fee": int.from_bytes(b[256:260], "little"),
             "features": b[1]}
        vaults.append(v)
    # staging balances
    keys = [x["vault_a"] for x in vaults] + [x["vault_b"] for x in vaults]
    res = get_accounts(keys, encoding="base64")
    for i, x in enumerate(vaults):
        for j, f in enumerate(("staging_a", "staging_b")):
            acct = res[i * 2 + j]
            x[f] = int.from_bytes(base64.b64decode(acct["data"][0])[64:72], "little") if acct else None
    result["steps"]["vaults"] = {"count": len(vaults), "vaults": vaults}
    log("vaults:", len(vaults))
    admins = sorted({v["admin"] for v in vaults})
    result["steps"]["admin_keys"] = admins
    log("admin keys:", admins)
except Exception as e:
    result["steps"]["vaults"] = {"error": redact(e)}
    log("vault enum FAILED:", redact(e))

# ---------- 3. simulations ----------
samples = json.load(open(os.path.join(A, "ix-full-samples.json")))

def run_sim(name, ix_list, payer, extra_signers=(), expect=None, expect_code=None):
    try:
        res = simulate(ix_list, payer, extra_signers=extra_signers)
        summ = summarize(res)
        err = summ["err"]
        code = None
        if isinstance(err, dict):
            try:
                code = err["InstructionError"][1].get("Custom")
            except Exception:
                code = None
        ok = (err is None) if expect == "success" else (err is not None)
        if expect_code is not None:
            ok = ok and (code == expect_code)
        entry = {"err": err, "cu": summ.get("unitsConsumed"), "expect": expect, "expect_code": expect_code,
                 "pass": ok}
        result["steps"].setdefault("sims", {})[name] = entry
        log(f"sim {name}: err={err} cu={summ.get('unitsConsumed')} expect={expect}/{expect_code} pass={ok}")
        return summ
    except Exception as e:
        result["steps"].setdefault("sims", {})[name] = {"error": redact(e)}
        log(f"sim {name} FAILED:", redact(e))
        return None

def metas_from(accts, signer_idx=0, ro_idx=()):
    return [(a, i == signer_idx, i not in ro_idx) for i, a in enumerate(accts)]

# a) self-withdraw by real LP holder (HTKMVZ) with min=0 -> expect success
try:
    w = samples["withdraw"][0]
    accs = list(w["accounts"]); data = b58decode(w["data"])
    data0 = data[:8] + data[8:16] + (0).to_bytes(8, "little") + (0).to_bytes(8, "little")
    holder = "FBHbrsAZicdG2qA5Z2uSiNjHEhbKEPC8dr4G4xTkF94a"
    lp_ata = "3BJqPCwQ9gzinv4xpxEqjvH7t64P5pFXkUaENuV2EVNv"
    ata_a = "9t1zooRd6cVD2AXf3HDv4XypRUmS9cj2AG3EXjUB6CJW"
    ata_b = "Gft1EFB5LF1XJJAVnmEDkVDGFR3UgXACt343vjqMBmvh"
    accs[0] = holder; accs[3] = lp_ata; accs[1] = ata_a; accs[2] = ata_b
    ro = {4, 8, 9, 15}
    run_sim("withdraw_self_holder", [{"program_id": PROG, "accounts": metas_from(accs, 0, ro), "data": data0}],
            holder, expect="success")
    # b) attacker withdraws victim's LP -> expect revert (SPL owner mismatch = Custom 4)
    attacker = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"
    accs2 = list(accs); accs2[0] = attacker
    run_sim("withdraw_attacker_victim_lp", [{"program_id": PROG, "accounts": metas_from(accs2, 0, ro), "data": data0}],
            attacker, expect="revert", expect_code=4)
except Exception as e:
    log("withdraw sims FAILED:", redact(e))

# c) collectFees with attacker fee account -> expect IncorrectFeeOwner
try:
    cf = samples["collect_fees"][0]
    accf = list(cf["accounts"])
    attacker2 = "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU"
    r = rpc("getTokenAccountsByOwner", [attacker2, {"mint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"},
                                        {"encoding": "jsonParsed"}])
    att_ata = ((r or {}).get("value") or [{}])[0].get("pubkey")
    if att_ata:
        accf[10] = att_ata
    ro_f = {3, 4, 13}
    run_sim("collect_fees_attacker_fee_account", [{"program_id": PROG, "accounts": metas_from(accf, 0, ro_f), "data": b58decode(cf["data"])}],
            accf[0], expect="revert", expect_code=6019)
except Exception as e:
    log("collect_fees sim FAILED:", redact(e))

# d) externalSwapSetup without MM signer, paired with cleanup so the ix_utils check passes -> expect AccountNotSigner (3010)
try:
    es = samples["external_swap_setup"][0]
    ec = samples["external_swap_cleanup"][0]
    acce = list(es["accounts"]); acce_c = list(ec["accounts"])
    attacker = "BN1TEzniqHnv6huecisEtpaz2thUnmPCBwi9THcYriLU"  # unprivileged LP holder (not the MM)
    metas_e = [(a, False, i in (1, 2)) for i, a in enumerate(acce)]
    metas_c = [(a, False, False) for i, a in enumerate(acce_c)]
    run_sim("external_swap_setup_no_mm_sig",
            [{"program_id": PROG, "accounts": metas_e, "data": b58decode(es["data"])},
             {"program_id": PROG, "accounts": metas_c, "data": b58decode(ec["data"])}],
            attacker, expect="revert", expect_code=3010)
except Exception as e:
    log("extswap sim FAILED:", redact(e))

# e) updateConfig without admin -> expect InccorectAdminKey
try:
    VK = "6JwmYu4cveodYbXYtJ3zxTTuSR9mXZb6iENNMnXdUwBK"
    v = json.load(open(os.path.join(A, "recon1.json")))["vaults"][VK]
    args = (b58decode(v["market_making_key"]) + b58decode(v["fee_owner"]) + (v["performance_fee"]).to_bytes(4, "little")
            + (0).to_bytes(4, "little") + (v["market_making_fee"]).to_bytes(4, "little") + bytes([v["strategy"]])
            + b58decode(v["stake_pool"]) + bytes([v["features_enabled"]]))
    data = disc("global:update_config") + args
    attacker = "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"
    run_sim("update_config_no_admin", [{"program_id": PROG, "accounts": [(attacker, True, True), (VK, False, True)], "data": data}],
            attacker, expect="revert", expect_code=6018)
except Exception as e:
    log("updateConfig sim FAILED:", redact(e))

json.dump(result, open(os.path.join(OUT, "verify.json"), "w"), indent=1)
log("\nWROTE", os.path.join(OUT, "verify.json"))
log("SUMMARY:", json.dumps({k: (v if not isinstance(v, dict) else {kk: vv for kk, vv in v.items() if kk != "vaults"})
                            for k, v in result["steps"].items()})[:2000])
