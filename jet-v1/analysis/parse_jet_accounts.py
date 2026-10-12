#!/usr/bin/env python3
"""Parse Jet v1 on-chain accounts (Market/Reserve/Obligation) per Dec-2021 v0.2.0 layout.

Layouts (verified against on-chain sizes):
  Market   space 12808 = 8 disc + 12800
  Reserve  space 2056  = 8 disc + 2048
  Obligation space 4616 = 8 disc + 4608
Number = U192 (3 x u64 LE), PRECISION = 15.
Read-only. Input: JSON from getAccountInfo / getProgramAccounts.
"""
import json, base64, sys

def pk(b):
    from solders.pubkey import Pubkey
    return str(Pubkey.from_bytes(bytes(b)))

def u16(b, o): return int.from_bytes(b[o:o+2], 'little')
def u32(b, o): return int.from_bytes(b[o:o+4], 'little')
def i32(b, o): return int.from_bytes(b[o:o+4], 'little', signed=True)
def u64(b, o): return int.from_bytes(b[o:o+8], 'little')
def i64(b, o): return int.from_bytes(b[o:o+8], 'little', signed=True)

PREC = 10**15
def num(b, o):
    """Decode 24-byte U192 Number -> float (value / 1e15)."""
    lo = int.from_bytes(b[o:o+8], 'little')
    mid = int.from_bytes(b[o+8:o+16], 'little')
    hi = int.from_bytes(b[o+16:o+24], 'little')
    v = lo + (mid << 64) + (hi << 128)
    return v / PREC

def parse_market(data):
    m = data[8:]
    out = {
        "version": u32(m, 0), "quote_exponent": i32(m, 4),
        "quote_currency": m[8:23].rstrip(b'\x00').decode(errors='replace'),
        "authority_bump_seed": m[23],
        "authority_seed": pk(m[24:56]), "market_authority": pk(m[56:88]),
        "owner": pk(m[88:120]), "quote_token_mint": pk(m[120:152]),
        "flags": u64(m, 152),
    }
    reserves = []
    cache = []
    for i in range(32):
        off = 512 + i * 384
        rpk = m[off:off+32]
        if rpk == bytes(32):
            break
        reserves.append(pk(rpk))
        c = off + 112
        cache.append({
            "price": num(m, c),
            "deposit_note_exchange_rate": num(m, c+24),
            "loan_note_exchange_rate": num(m, c+48),
            "min_collateral_ratio": num(m, c+72),
            "liquidation_bonus_bps": u16(m, c+96),
            "last_updated_slot": u64(m, c+256),
            "invalidated": m[c+264],
        })
    out["reserves"] = reserves
    out["cache"] = cache
    return out

def parse_reserve(data):
    r = data[8:]
    out = {
        "version": u16(r, 0), "index": u16(r, 2), "exponent": i32(r, 4),
        "market": pk(r[8:40]),
        "pyth_oracle_price": pk(r[40:72]),
        "pyth_oracle_product": pk(r[72:104]),
        "token_mint": pk(r[104:136]),
        "deposit_note_mint": pk(r[136:168]),
        "loan_note_mint": pk(r[168:200]),
        "vault": pk(r[200:232]),
        "fee_note_vault": pk(r[232:264]),
        "dex_swap_tokens": pk(r[264:296]),
        "dex_open_orders": pk(r[296:328]),
        "dex_market": pk(r[328:360]),
    }
    cfg = 768
    out["config"] = {
        "utilization_rate_1": u16(r, cfg), "utilization_rate_2": u16(r, cfg+2),
        "borrow_rate_0": u16(r, cfg+4), "borrow_rate_1": u16(r, cfg+6),
        "borrow_rate_2": u16(r, cfg+8), "borrow_rate_3": u16(r, cfg+10),
        "min_collateral_ratio": u16(r, cfg+12),
        "liquidation_premium": u16(r, cfg+14),
        "manage_fee_collection_threshold": u64(r, cfg+16),
        "manage_fee_rate": u16(r, cfg+24),
        "loan_origination_fee": u16(r, cfg+26),
        "confidence_threshold": u16(r, cfg+30),
        "liquidation_dex_trade_max": u64(r, cfg+32),
    }
    st = 1536
    out["state"] = {
        "accrued_until": i64(r, st),
        "outstanding_debt": num(r, st+8),
        "uncollected_fees": num(r, st+32),
        "total_deposits": u64(r, st+56),
        "total_deposit_notes": u64(r, st+64),
        "total_loan_notes": u64(r, st+72),
    }
    return out

def parse_position(b, o):
    acct = b[o:o+32]
    if acct == bytes(32):
        return None
    return {
        "account": pk(acct),
        "amount": num(b, o+32),
        "side": u32(b, o+56),
        "reserve_index": u16(b, o+60),
    }

def parse_obligation(data):
    o = data[8:]
    out = {
        "version": u32(o, 0),
        "market": pk(o[8:40]), "owner": pk(o[40:72]),
        "cached_collateral_value": num(o, 256),
        "cached_loan_value": num(o, 280),
        "cache_last_updated": u64(o, 256+240),
        "cache_invalidated": o[256+248],
    }
    coll = [parse_position(o, 512 + i*128) for i in range(16)]
    loans = [parse_position(o, 2560 + i*128) for i in range(16)]
    out["collateral"] = [p for p in coll if p]
    out["loans"] = [p for p in loans if p]
    return out

if __name__ == "__main__":
    src = json.load(open(sys.argv[1]))
    kind = sys.argv[2] if len(sys.argv) > 2 else "auto"
    for addr, v in src.items():
        data = base64.b64decode(v["data"])
        disc = data[:8].hex()
        if disc == "dbbed53700e3c69a":
            print("MARKET", addr); print(json.dumps(parse_market(data), indent=1))
        elif disc == "2bf2ccca1af73b7f":
            print("RESERVE", addr); print(json.dumps(parse_reserve(data), indent=1))
        elif disc == "a8ce8d6a584caca7":
            print("OBLIGATION", addr); print(json.dumps(parse_obligation(data), indent=1))
        else:
            print("UNKNOWN", addr, disc, "len", len(data))
