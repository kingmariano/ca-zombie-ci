#!/usr/bin/env python3
"""Recon pass 1: program meta, IDL account, ClpVault enumeration + decode, token accounts, mints."""
import base64, json, sys, time
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"

out = {}

# --- 1. program + upgrade authority ---
a = get_account(PROG)
pd_addr = programdata_address(PROG)
pda = get_account(pd_addr)
raw = base64.b64decode(pda["data"][0])
slot = int.from_bytes(raw[4:12], "little")
has_auth = raw[12]
auth = b58encode(raw[13:45]) if has_auth else None
out["program"] = {"program_id": PROG, "owner": a["owner"], "executable": a["executable"],
                  "lamports": a["lamports"], "space": a["space"],
                  "programdata": pd_addr, "deployed_slot": slot, "upgrade_authority": auth,
                  "programdata_len": len(raw)}
if auth:
    ua = get_account(auth)
    out["upgrade_authority_account"] = {
        "lamports": ua["lamports"] if ua else None,
        "owner": ua["owner"] if ua else None,
        "executable": ua["executable"] if ua else None,
        "space": ua.get("space") if ua else None,
    }

# --- 2. anchor IDL account check ---
idl_addr, bump = find_pda(["anchor:idl"], PROG)
out["idl_pda"] = {"address": idl_addr, "bump": bump}
ia = get_account(idl_addr)
out["idl_account_present"] = ia is not None
if ia:
    iraw = base64.b64decode(ia["data"][0])
    out["idl_account_len"] = len(iraw)
    out["idl_authority"] = b58encode(iraw[8:40])
    try:
        import zlib
        dlen = int.from_bytes(iraw[40:44], "little")
        payload = iraw[44:44+dlen]
        decomp = zlib.decompress(payload)
        open("/home/heisenberg/CA/armada/analysis/onchain-idl.json", "wb").write(decomp)
        out["idl_decompressed_len"] = len(decomp)
    except Exception as e:
        out["idl_decompress_error"] = redact(e)

# --- 3. enumerate ClpVault accounts (full data) ---
accs = get_program_accounts(PROG, filters=[{"memcmp": {"offset": 0, "bytes": b58encode(disc("account:ClpVault"))}}],
                            encoding="base64", timeout=180)
out["clp_vault_count"] = len(accs)

def pk(b, off):
    return b58encode(b[off:off+32])

def decode_vault(data: bytes):
    # struct starts at 8 (anchor discriminator)
    b = data[8:]
    def u32(o): return int.from_bytes(b[o:o+4], "little")
    def u64(o): return int.from_bytes(b[o:o+8], "little")
    d = {
        "bump_seed": b[0], "features_enabled": b[1],
        "nonce": int.from_bytes(b[16:18], "little"),
        "clp": pk(b, 32), "lp_mint": pk(b, 64), "lp_mint_bump": b[96],
        "token_mint_a": pk(b, 112), "token_vault_a": pk(b, 144),
        "token_mint_b": pk(b, 176), "token_vault_b": pk(b, 208),
        "performance_fee": u32(240), "withdrawal_fee": u32(256), "market_making_fee": u32(272),
        "strategy": b[288],
        "market_making_key": pk(b, 304), "admin_key": pk(b, 336), "fee_owner": pk(b, 368),
        "num_active_positions": b[400],
        "position_bundle_token_account": pk(b, 416),
        "position_bundle_mint": pk(b, 448),
        "position_bundle": pk(b, 480),
    }
    positions = []
    for i in range(5):
        o = 512 + i * 320
        positions.append({
            "position_key": pk(b, o),
            "lower_tick": int.from_bytes(b[o+32:o+36], "little", signed=True),
            "upper_tick": int.from_bytes(b[o+48:o+52], "little", signed=True),
        })
    d["positions"] = positions
    o = 512 + 5 * 320
    d["initial_token_ratio"] = {"token_a": u64(o), "token_b": u64(o+8)}
    d["stake_pool"] = pk(b, o + 16)
    o2 = o + 16 + 32
    d["ratio_cache"] = {"total_token_a": u64(o2), "total_token_b": u64(o2+8), "lp_supply": u64(o2+16),
                        "cached_at": int.from_bytes(b[o2+24:o2+32], "little", signed=True)}
    d["_struct_len"] = len(b)
    return d

vaults = {}
for acc in accs:
    key = acc["pubkey"]
    data = base64.b64decode(acc["account"]["data"][0])
    try:
        vaults[key] = decode_vault(data)
        vaults[key]["lamports"] = acc["account"]["lamports"]
        vaults[key]["data_len"] = len(data)
    except Exception as e:
        vaults[key] = {"decode_error": redact(e), "data_len": len(data)}
out["vaults"] = vaults
out["struct_len_seen"] = sorted({v.get("_struct_len") for v in vaults.values()})

json.dump(out, open("/home/heisenberg/CA/armada/analysis/recon1.json", "w"), indent=1)
print(json.dumps({k: out[k] for k in ["program", "upgrade_authority_account", "idl_pda", "idl_account_present",
                                      "clp_vault_count", "struct_len_seen"]}, indent=1))
print("vault keys:")
for k, v in vaults.items():
    print(k, v.get("token_mint_a", "?")[:8], v.get("token_mint_b", "?")[:8], "adm", v.get("admin_key", "?")[:8])
