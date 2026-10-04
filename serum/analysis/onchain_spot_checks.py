#!/usr/bin/env python3
"""H-22 source-audit on-chain spot checks (read-only, no secrets printed).

Checks:
 1. OpenBook v1 + Serum v3 program accounts: owner, programdata addr, upgrade authority.
 2. disable/fee authorities: account owner (System Program EOA vs PDA), lamports, signatures.
 3. V2 (permissioned) and Disabled market counts via getProgramAccounts (dataSize 388).
 4. Latest slot.
"""
import base64, json, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rpc import rpc, bytes_to_b58, u64le

OB = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
OB_AUTH = "GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA"
SERUM = "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin"
SERUM_SWEEP = "DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE"
SERUM_DISABLE = "5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V"
BPF_UPGRADEABLE = "BPFLoaderUpgradeab1e11111111111111111111111"
SYSTEM = "11111111111111111111111111111111"

out = {"slot": None, "checks": {}}

def acc(pk, enc="base64"):
    r = rpc("getAccountInfo", [pk, {"encoding": enc, "commitment": "finalized"}])
    return r["value"] if r else None

def check_program(name, pk):
    info = acc(pk)
    if info is None:
        out["checks"][name] = {"error": "account not found"}
        return
    res = {"address": pk, "owner": info["owner"], "executable": info["executable"],
           "lamports": info["lamports"], "data_len": len(base64.b64decode(info["data"][0]))}
    if info["owner"] == BPF_UPGRADEABLE:
        raw = base64.b64decode(info["data"][0])
        programdata = bytes_to_b58(raw[4:36])
        pd = acc(programdata)
        if pd:
            praw = base64.b64decode(pd["data"][0])
            res["programdata"] = programdata
            res["programdata_len"] = len(praw)
            res["deploy_slot"] = int.from_bytes(praw[4:12], "little")
            tag = praw[12]
            res["upgrade_authority"] = bytes_to_b58(praw[13:45]) if tag == 1 else None
    out["checks"][name] = res

check_program("openbook_v1_program", OB)
check_program("serum_v3_program", SERUM)

for name, pk in [("openbook_fee_sweeper", OB_AUTH), ("serum_fee_sweeper", SERUM_SWEEP),
                 ("serum_disable_authority", SERUM_DISABLE)]:
    info = acc(pk)
    res = None
    if info:
        res = {"address": pk, "owner": info["owner"], "lamports": info["lamports"],
               "data_len": len(base64.b64decode(info["data"][0])),
               "owner_is_system_program": info["owner"] == SYSTEM,
               "is_executable": info["executable"]}
    out["checks"][name] = res
    try:
        sigs = rpc("getSignaturesForAddress", [pk, {"limit": 5}])
        out["checks"][name + "_last_sigs"] = [
            {"signature": s["signature"], "slot": s["slot"], "blockTime": s.get("blockTime"),
             "err": s.get("err")} for s in (sigs or [])]
    except Exception as e:
        out["checks"][name + "_last_sigs"] = {"error": str(e)[:200]}
    time.sleep(0.4)

out["slot"] = rpc("getSlot", [{"commitment": "finalized"}])

# market flag variant counts (V1 init =3; disabled =3|128=131; V2 =3|512=515; V2 disabled=643)
for label, flags in [("v1_active", 3), ("v1_disabled", 131), ("v2_active", 515), ("v2_disabled", 643)]:
    try:
        res = rpc("getProgramAccounts", [OB, {
            "filters": [{"dataSize": 388}, {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(flags))}}],
            "encoding": "base64", "dataSlice": {"offset": 0, "length": 0}, "commitment": "finalized"}])
        out["checks"]["market_flags_" + label] = {"flags": flags, "count": len(res)}
    except Exception as e:
        out["checks"]["market_flags_" + label] = {"flags": flags, "error": str(e)[:200]}
    time.sleep(1.0)

print(json.dumps(out, indent=1))
with open(os.path.join(HERE, "onchain_spot_checks.json"), "w") as f:
    json.dump(out, f, indent=1)
