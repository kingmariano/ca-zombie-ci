#!/usr/bin/env python3
"""Francium live-state enumeration (read-only).

Phase 1: lending program FC81 accounts (reserves/market/misc).
Phase 2: LYF strategy states (raydium 903 / orca 967).
Phase 3: reward program pools (530).
Outputs JSON to analysis/.
"""
import json, base64, sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import rpc_call, get_program_accounts

OUT = os.path.dirname(os.path.abspath(__file__))
ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPH[r] + s
    pad = 0
    for c in b:
        if c == 0: pad += 1
        else: break
    return "1" * pad + s

def pk(buf, off):
    return b58(buf[off:off+32])

def u64(buf, off):
    return int.from_bytes(buf[off:off+8], "little")

def u128(buf, off):
    return int.from_bytes(buf[off:off+16], "little")

def u16(buf, off):
    return int.from_bytes(buf[off:off+2], "little")

# ---------------- RESERVE_LAYOUT (495) ----------------
RESERVE_FIELDS = [
    ("version", "u8"), ("last_updateSlot", "u64"), ("last_updateStale", "u8"),
    ("lendingMarket", "pk"), ("liquidityMintPubkey", "pk"), ("liquidityMint_decimals", "u8"),
    ("liquiditySupplyPubkey", "pk"), ("liquidityFeeReceiver", "pk"), ("oracle", "blob36"),
    ("liquidity_available_amount", "u64"), ("liquidity_borrowed_amount_wads", "u128"),
    ("liquidity_cumulative_borrowRate_wads", "u128"), ("liquidityMarketPrice", "u64"),
    ("shareMintPubkey", "pk"), ("shareMintTotalSupply", "u64"), ("shareSupplyPubkey", "pk"),
    ("creditMintPubkey", "pk"), ("creditMintTotalSupply", "u64"), ("creditSupplyPubkey", "pk"),
    ("threshold_1", "u8"), ("threshold_2", "u8"),
    ("base_1", "u8"), ("factor_1", "u16"), ("base_2", "u8"), ("factor_2", "u16"),
    ("base_3", "u8"), ("factor_3", "u16"), ("interestReverseRate", "u8"),
    ("accumulated_interestReverse", "u64"), ("padding", "blob108"),
]

def decode_layout(buf, fields):
    out = {}; off = 0
    for name, typ in fields:
        if typ == "u8": out[name] = buf[off]; off += 1
        elif typ == "u16": out[name] = u16(buf, off); off += 2
        elif typ == "u32": out[name] = int.from_bytes(buf[off:off+4], "little"); off += 4
        elif typ == "u64": out[name] = u64(buf, off); off += 8
        elif typ == "u128": out[name] = u128(buf, off); off += 16
        elif typ == "pk": out[name] = pk(buf, off); off += 32
        elif typ.startswith("blob"): off += int(typ[4:])
        else: raise ValueError(typ)
    out["_size"] = off
    return out

def decode_reserve(buf):
    d = decode_layout(buf, RESERVE_FIELDS)
    assert d["_size"] == 495, d["_size"]
    return d

# ---------------- IDL-driven decoding ----------------
def idl_fields(idl_path, account_name):
    idl = json.load(open(idl_path))
    acc = next(a for a in idl["accounts"] if a["name"] == account_name)
    fields = []
    for f in acc["type"]["fields"]:
        t = f["type"]
        if isinstance(t, str):
            fields.append((f["name"], {"publicKey": "pk"}.get(t, t)))
        elif isinstance(t, dict) and "array" in t:
            fields.append((f["name"], f"blob{t['array'][1]}"))
        elif isinstance(t, dict) and "defined" in t:
            fields.append((f["name"], "defined:" + t["defined"]))
        else:
            raise ValueError(str(t))
    return fields

def decode_idl(buf, fields, skip=8):
    return decode_layout(buf[skip:], fields)

RAY_STRAT_FIELDS = None
ORCA_STRAT_FIELDS = None

def decode_ray_strat(buf):
    global RAY_STRAT_FIELDS
    if RAY_STRAT_FIELDS is None:
        RAY_STRAT_FIELDS = idl_fields(os.path.join(OUT, "idl_raydium.json"), "StrategyState")
    return decode_idl(buf, RAY_STRAT_FIELDS)

def decode_orca_strat(buf):
    global ORCA_STRAT_FIELDS
    if ORCA_STRAT_FIELDS is None:
        ORCA_STRAT_FIELDS = idl_fields(os.path.join(OUT, "idl_orca.json"), "StrategyState")
    return decode_idl(buf, ORCA_STRAT_FIELDS)

# ---------------- FARM_LAYOUT (530) ----------------
FARM = [
    ("version","u8"),("is_dual_rewards","u8"),("admin","pk"),("pool_authority","pk"),
    ("token_program_id","pk"),("staked_token_mint","pk"),("staked_token_account","pk"),  # Dappio order: admin, pool_authority, token_program_id
    ("rewards_token_mint","pk"),("rewards_token_account","pk"),("rewards_token_mint_b","pk"),
    ("rewards_token_account_b","pk"),("pool_stake_cap","u64"),("user_stake_cap","u64"),
    ("rewards_start_slot","u64"),("rewards_end_slot","u64"),("rewards_per_day","u64"),
    ("rewards_start_slot_b","u64"),("rewards_end_slot_b","u64"),("rewards_per_day_b","u64"),
    ("total_staked_amount","u64"),("last_update_slot","u64"),
    ("accumulated_rewards_per_share","u128"),("accumulated_rewards_per_share_b","u128"),
    ("padding","blob128"),
]

def decode_farm(buf):
    d = decode_layout(buf, FARM)
    assert d["_size"] == 530, d["_size"]  # total account size (no anchor discriminator)
    return d

def gpa_full(program, filters=None):
    return get_program_accounts(program, filters=filters, encoding="base64")

def main():
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"
    result = {}

    if phase in ("all", "lend"):
        accts = gpa_full("FC81tbGt6JWRXidaWYFXxGnTk4VgobhJHATvTRVMqgWj")
        with open(os.path.join(OUT, "raw_lend_program_accounts.json"), "w") as f:
            json.dump(accts, f)
        by_size = {}
        for a in accts:
            by_size.setdefault(a["account"].get("space"), []).append(a)
        reserves = []
        misc = []
        for a in accts:
            raw = base64.b64decode(a["account"]["data"][0])
            if len(raw) == 495:
                d = decode_reserve(raw)
                d["reserve"] = a["pubkey"]
                reserves.append(d)
            else:
                misc.append({"pubkey": a["pubkey"], "size": len(raw), "data_b64": a["account"]["data"][0]})
        result["reserves"] = reserves
        result["misc"] = misc
        print(f"FC81: total={len(accts)} reserves={len(reserves)} misc={len(misc)}")
        for m in misc:
            raw = base64.b64decode(m["data_b64"])
            print("  misc", m["size"], m["pubkey"], "first48:", raw[:48].hex())
            # try to identify 32-byte pubkey windows
            for off in (0,1,2,4,8,10):
                if off+32 <= len(raw):
                    print(f"     window+{off}: {b58(raw[off:off+32])}")
        json.dump(result, open(os.path.join(OUT, "lend_state.json"), "w"), indent=1)

    if phase in ("all", "strategies"):
        strategies = {}
        for name, pid, size, dec in [
            ("raydium", "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N", 903, decode_ray_strat),
            ("orca", "DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP", 967, decode_orca_strat),
        ]:
            accts = gpa_full(pid, filters=[{"dataSize": size}])
            out = []
            for a in accts:
                raw = base64.b64decode(a["account"]["data"][0])
                d = dec(raw)
                d["strategy"] = a["pubkey"]
                out.append(d)
            strategies[name] = out
            print(f"{name}: strategy accounts={len(out)}")
        json.dump(strategies, open(os.path.join(OUT, "strategies.json"), "w"), indent=1)
        result["strategies"] = strategies

    if phase in ("all", "farms"):
        accts = gpa_full("3Katmm9dhvLQijAvomteYMo6rfVbY5NaCRNq9ZBqBgr6", filters=[{"dataSize": 530}])
        farms = []
        for a in accts:
            raw = base64.b64decode(a["account"]["data"][0])
            d = decode_farm(raw)
            d["farm"] = a["pubkey"]
            farms.append(d)
        print(f"farms: {len(farms)}")
        json.dump(farms, open(os.path.join(OUT, "farms.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
