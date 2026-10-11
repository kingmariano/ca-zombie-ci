#!/usr/bin/env python3
"""Taiga Acala - archive-state forensics: find when Pools[0] last changed and rate history.
Read-only. Uses public RPC archive state (state_getStorage at block hashes)."""
import json, hashlib, urllib.request, time, sys

M = (1 << 64) - 1
P1 = 0x9E3779B185EBCA87; P2 = 0xC2B2AE3D27D4EB4F; P3 = 0x165667B19E3779F9
P4 = 0x85EBCA77C2B2AE63; P5 = 0x27D4EB2F165667C5
def rotl(x, r): return ((x << r) | (x >> (64 - r))) & M
def xxh64(data, seed=0):
    n = len(data); i = 0
    if n >= 32:
        v1 = (seed + P1 + P2) & M; v2 = (seed + P2) & M; v3 = seed & M; v4 = (seed - P1) & M
        while i + 32 <= n:
            for vi in range(4):
                k = int.from_bytes(data[i:i+8], 'little'); i += 8
                if vi == 0: v1 = (rotl((v1 + k * P2) & M, 31) * P1) & M
                elif vi == 1: v2 = (rotl((v2 + k * P2) & M, 31) * P1) & M
                elif vi == 2: v3 = (rotl((v3 + k * P2) & M, 31) * P1) & M
                else: v4 = (rotl((v4 + k * P2) & M, 31) * P1) & M
        h = (rotl(v1, 1) + rotl(v2, 7) + rotl(v3, 12) + rotl(v4, 18)) & M
        for v in (v1, v2, v3, v4):
            h = ((h ^ (rotl((v * P2) & M, 31) * P1) & M) * P1 + P4) & M
    else:
        h = (seed + P5) & M
    h = (h + n) & M
    while i + 8 <= n:
        k = int.from_bytes(data[i:i+8], 'little'); i += 8
        h = (rotl((h ^ (rotl((k * P2) & M, 31) * P1) & M), 27) * P1 + P4) & M
    if i + 4 <= n:
        k = int.from_bytes(data[i:i+4], 'little'); i += 4
        h = (rotl((h ^ (k * P1) & M), 23) * P2 + P3) & M
    while i < n:
        h = (rotl((h ^ (data[i] * P5) & M), 11) * P1) & M; i += 1
    h ^= h >> 33; h = (h * P2) & M; h ^= h >> 29; h = (h * P3) & M; h ^= h >> 32
    return h
def twox64(b): return xxh64(b, 0).to_bytes(8, 'little')
def twox128(b): return xxh64(b, 0).to_bytes(8, 'little') + xxh64(b, 1).to_bytes(8, 'little')
def blake2_128_concat(b): return hashlib.blake2b(b, digest_size=16).digest() + b

URL = "https://acala-rpc-0.aca-api.network"
def rpc(method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                j = json.loads(r.read().decode())
            if "error" in j: raise RuntimeError(j["error"])
            return j.get("result")
        except Exception as e:
            last = e; time.sleep(1)
    raise RuntimeError(f"{method} failed: {last}")

POOLS0 = "0x" + (twox128(b"StableAsset") + twox128(b"Pools") + blake2_128_concat((0).to_bytes(4, 'little'))).hex()
TSB = "0x" + (twox128(b"Homa") + twox128(b"TotalStakingBonded")).hex()
LDOT_ISSUANCE = "0x" + (twox128(b"Tokens") + twox128(b"TotalIssuance") + twox64(bytes([0, 3]))).hex()
TVL = "0x" + (twox128(b"Homa") + twox128(b"TotalVoidLiquid")).hex()

def get_at(key, block_hash):
    return rpc("state_getStorage", [key, block_hash])

def header_at(n):
    h = rpc("chain_getBlockHash", [n])
    return h

def read_pool_state(n):
    h = header_at(n)
    if not h: return None
    v = get_at(POOLS0, h)
    if not v or v == "0x": return None
    b = bytes.fromhex(v[2:])
    # extract total_supply & balances: parse minimal (see fetch_state.py decoder)
    # fields: pool_asset(5 bytes: 03+u32), assets vec(1 + 2*2), precisions vec (1 + 2*16),
    # mint_fee,swap_fee,redeem_fee,total_supply (u128 x4), a(u128), a_block(u32), future_a(u128), future_a_block(u32)
    i = 0
    i += 5  # pool_asset StableAssetPoolToken(0)
    na = b[i]; i += 1
    i += na * 2  # Token(u8) each
    np_ = b[i]; i += 1
    precisions = [int.from_bytes(b[i+16*j:i+16*(j+1)], 'little') for j in range(np_)]; i += np_ * 16
    mint_fee = int.from_bytes(b[i:i+16], 'little'); i += 16
    swap_fee = int.from_bytes(b[i:i+16], 'little'); i += 16
    redeem_fee = int.from_bytes(b[i:i+16], 'little'); i += 16
    total_supply = int.from_bytes(b[i:i+16], 'little'); i += 16
    a = int.from_bytes(b[i:i+16], 'little'); i += 16
    a_block = int.from_bytes(b[i:i+4], 'little'); i += 4
    future_a = int.from_bytes(b[i:i+16], 'little'); i += 16
    future_a_block = int.from_bytes(b[i:i+4], 'little'); i += 4
    nb = b[i]; i += 1
    balances = [int.from_bytes(b[i+16*j:i+16*(j+1)], 'little') for j in range(nb)]; i += nb * 16
    return {"block": n, "total_supply": total_supply, "balances": balances, "a": a,
            "a_block": a_block, "raw_len": len(b)}

def read_rate_inputs(n):
    h = header_at(n)
    if not h: return None
    tsb = get_at(TSB, h); li = get_at(LDOT_ISSUANCE, h); tv = get_at(TVL, h)
    def u(v): return int.from_bytes(bytes.fromhex(v[2:])[:16], 'little') if v and v != "0x" else None
    tsb, li, tv = u(tsb), u(li), u(tv)
    rate = (tsb / li) if tsb and li else None
    return {"block": n, "totalStakingBonded": tsb, "ldotIssuance": li, "totalVoidLiquid": tv, "rate": rate}

def main():
    cur = int(rpc("chain_getHeader", [])["number"], 16)
    print("current block:", cur)
    cur_pool = read_pool_state(cur)
    print("current pool:", json.dumps(cur_pool))
    cur_rate = read_rate_inputs(cur)
    print("current rate inputs:", json.dumps(cur_rate))

    # archive availability test
    try:
        t = read_pool_state(cur - 1_000_000)
        print("archive @-1M:", json.dumps(t)[:200])
    except Exception as e:
        print("archive @-1M FAILED:", e)

    # exponential search for last change of Pools[0]
    ref = cur_pool
    last_change = None
    prev_same = cur
    for delta in [10, 100, 1000, 10000, 50000, 200000, 1000000, 3000000, 6000000]:
        n = cur - delta
        if n < 1: break
        try:
            st = read_pool_state(n)
        except Exception as e:
            print("read failed at", n, e); break
        if st is None:
            print(delta, "no pool state"); continue
        same = (st["total_supply"] == ref["total_supply"] and st["balances"] == ref["balances"])
        print(f"-{delta}: same={same} total_supply={st['total_supply']} balances={st['balances']}")
        if not same:
            last_change = n
            break
    if last_change:
        lo, hi = last_change, last_change + 1000000
        # binary search first block (>=lo) where state equals current
        while lo + 1 < hi:
            mid = (lo + hi) // 2
            st = read_pool_state(mid)
            if st and st["total_supply"] == ref["total_supply"] and st["balances"] == ref["balances"]:
                hi = mid
            else:
                lo = mid
        print("last change block (approx):", lo, "first matching current:", hi)
        for n in [lo - 1, lo, hi, hi + 1]:
            st = read_pool_state(n)
            rt = read_rate_inputs(n)
            print(json.dumps({"pool": st, "rate_inputs": rt}))

if __name__ == "__main__":
    main()
