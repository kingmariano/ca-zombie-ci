#!/usr/bin/env python3
"""Recon pass 2: per-vault token accounts, LP mints, admin keys, program account space, recent activity."""
import base64, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
r1 = json.load(open("/home/heisenberg/CA/armada/analysis/recon1.json"))
vaults = r1["vaults"]
out = {"vaults": {}}

TOKEN_PROGRAM = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"

# --- per-vault: token vaults, lp mint, positions, bundle ---
all_extra_accounts = set()
for vk, v in vaults.items():
    d = {}
    for name in ("token_vault_a", "token_vault_b", "lp_mint", "position_bundle_token_account",
                 "position_bundle", "position_bundle_mint"):
        all_extra_accounts.add(v[name])
    for i, p in enumerate(v["positions"]):
        if p["position_key"] != "11111111111111111111111111111111":
            all_extra_accounts.add(p["position_key"])
    d["raw"] = v
    out["vaults"][vk] = d

keys = sorted(all_extra_accounts)
print(f"extra accounts: {len(keys)}")

# fetch all in batches, jsonParsed for token accounts, base64 for others
info = {}
for i in range(0, len(keys), 100):
    chunk = keys[i:i+100]
    res = get_accounts(chunk, encoding="base64")
    for k, a in zip(chunk, res):
        info[k] = a
print("fetched", len(info))

# classify + parse token accounts
tok = {}
for k, a in info.items():
    if not a:
        tok[k] = None
        continue
    raw = base64.b64decode(a["data"][0]) if isinstance(a["data"], list) else None
    e = {"owner_program": a["owner"], "lamports": a["lamports"], "len": len(raw) if raw else None}
    if a["owner"] == TOKEN_PROGRAM and raw and len(raw) >= 165:
        mint = b58encode(raw[0:32]); owner = b58encode(raw[32:64])
        amt = int.from_bytes(raw[64:72], "little")
        dec = raw[44]  # state? no: decimals is in mint. For token account, offset 64=amount, 72=delegate...
        e.update({"kind": "token_account", "mint": mint, "account_owner": owner, "amount": amt})
    elif a["owner"] == TOKEN_PROGRAM and raw and len(raw) == 82:
        dec = raw[44]
        e.update({"kind": "mint", "mint_authority": b58encode(raw[0:32]) if raw[0] == 1 else None,
                  "supply": int.from_bytes(raw[36:44], "little"), "decimals": dec,
                  "freeze_authority": b58encode(raw[46:78]) if raw[46] == 1 else None})
    elif a["owner"] == "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc" and raw:
        e.update({"kind": "whirlpool" if len(raw) == 653 else ("position" if len(raw) == 216 else "orca_other")})
        if len(raw) == 216:
            e.update({"whirlpool": b58encode(raw[0:32]),
                      "position_mint": b58encode(raw[32:64]),
                      "liquidity": int.from_bytes(raw[64:80], "little"),
                      "tick_lower": int.from_bytes(raw[80:84], "little", signed=True),
                      "tick_upper": int.from_bytes(raw[84:88], "little", signed=True),
                      "fee_owed_a": int.from_bytes(raw[104:112], "little"),
                      "fee_owed_b": int.from_bytes(raw[128:136], "little")})
        if len(raw) == 653:
            e.update({"whirlpools_config": b58encode(raw[0:32]),
                      "tick_spacing": int.from_bytes(raw[33:35], "little"),
                      "fee_rate": int.from_bytes(raw[37:39], "little"),
                      "liquidity": int.from_bytes(raw[41:57], "little"),
                      "sqrt_price": int.from_bytes(raw[57:73], "little"),
                      "tick_current": int.from_bytes(raw[73:77], "little", signed=True),
                      "token_mint_a": b58encode(raw[93:125]),
                      "token_vault_a": b58encode(raw[125:157]),
                      "token_mint_b": b58encode(raw[173:205]),
                      "token_vault_b": b58encode(raw[205:237])})
    elif a["owner"] == TOKEN_PROGRAM and raw and len(raw) == 64:
        e.update({"kind": "position_bundle", "bundle_mint": b58encode(raw[0:32]), "bitmap": raw[32:64].hex()})
    tok[k] = e

out["accounts"] = tok

# --- LP mint holders + supplies ---
lp_mints = sorted({v["lp_mint"] for v in vaults.values()})
lp_supply = {}
for m in lp_mints:
    s = rpc("getTokenSupply", [m])
    lp_supply[m] = s.get("value") if s else None
out["lp_supply"] = lp_supply
print("LP supplies fetched:", len(lp_supply))

json.dump(out, open("/home/heisenberg/CA/armada/analysis/recon2.json", "w"), indent=1)
print("written recon2.json")
