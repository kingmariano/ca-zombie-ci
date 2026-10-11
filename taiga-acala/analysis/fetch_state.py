#!/usr/bin/env python3
"""Taiga Acala (L2 Phase-2) - live state fetch. Read-only, public RPC only.
Reuses xxhash64/ss58 helpers (pure python) from l2-triage-c probe.
Dumps raw storage hex + decoded values to analysis/state-<block>.json
"""
import json, hashlib, urllib.request, time, sys, os

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

B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58decode(s):
    num = 0
    for c in s: num = num * 58 + B58.index(c)
    full = num.to_bytes((num.bit_length() + 7) // 8, 'big')
    pad = len(s) - len(s.lstrip('1'))
    return b'\x00' * pad + full

def ss58_decode(addr):
    raw = b58decode(addr)
    return raw[1:-2]

ENDPOINTS = [
    "https://acala-rpc-0.aca-api.network",
    "https://acala-rpc-1.aca-api.network",
    "https://acala-rpc-2.aca-api.network",
    "https://acala-rpc-3.aca-api.network",
]

def rpc(url, method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={
                "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"})
            with urllib.request.urlopen(req, timeout=45) as r:
                j = json.loads(r.read().decode())
            if "error" in j: raise RuntimeError(j["error"])
            return j.get("result")
        except Exception as e:
            last = e; time.sleep(1.5)
    raise RuntimeError(f"{method} failed on {url}: {last}")

def rpc_any(method, params):
    errs = []
    for url in ENDPOINTS:
        try:
            return rpc(url, method, params), url
        except Exception as e:
            errs.append(f"{url}: {e}")
    raise RuntimeError("all endpoints failed: " + " | ".join(errs))

def get_storage(key_hex):
    v, url = rpc_any("state_getStorage", [key_hex])
    return v, url

# ---------------- SCALE decoding (minimal) ----------------
class Scale:
    def __init__(self, b): self.b = b; self.i = 0
    def u8(self):
        v = self.b[self.i]; self.i += 1; return v
    def u16(self):
        v = int.from_bytes(self.b[self.i:self.i+2], 'little'); self.i += 2; return v
    def u32(self):
        v = int.from_bytes(self.b[self.i:self.i+4], 'little'); self.i += 4; return v
    def u128(self):
        v = int.from_bytes(self.b[self.i:self.i+16], 'little'); self.i += 16; return v
    def vec(self, fn):
        n = self.u32(); return [fn() for _ in range(n)]
    def fixed(self, n):
        v = self.b[self.i:self.i+n]; self.i += n; return v

def dec_token_symbol(s):
    return {0: "ACA", 1: "AUSD", 2: "DOT", 3: "LDOT", 4: "TAP", 128: "KAR", 129: "KUSD",
            130: "KSM", 131: "LKSM", 132: "TAI", 168: "BNC"}.get(s, f"Token({s})")

def dec_dexshare(s):
    v = s.u8()
    if v == 0: return ("Token", dec_token_symbol(s.u8()))
    if v == 1: return ("Erc20", s.fixed(20).hex())
    if v == 2: return ("LiquidCrowdloan", s.u32())
    if v == 3: return ("ForeignAsset", s.u16())
    if v == 4: return ("StableAssetPoolToken", s.u32())
    return (f"Unknown({v})", None)

def dec_currency(s):
    v = s.u8()
    if v == 0: return ("Token", dec_token_symbol(s.u8()))
    if v == 1: return ("DexShare", dec_dexshare(s), dec_dexshare(s))
    if v == 2: return ("Erc20", s.fixed(20).hex())
    if v == 3: return ("StableAssetPoolToken", s.u32())
    if v == 4: return ("LiquidCrowdloan", s.u32())
    if v == 5: return ("ForeignAsset", s.u16())
    return (f"Unknown({v})", None)

def dec_account(s):
    return "0x" + s.fixed(32).hex()

def dec_pool_info(hexstr):
    b = bytes.fromhex(hexstr[2:])
    s = Scale(b)
    pool = {
        "pool_asset": dec_currency(s),
        "assets": s.vec(lambda: dec_currency(s)),
        "precisions": s.vec(s.u128),
        "mint_fee": s.u128(),
        "swap_fee": s.u128(),
        "redeem_fee": s.u128(),
        "total_supply": s.u128(),
        "a": s.u128(),
        "a_block": s.u32(),
        "future_a": s.u128(),
        "future_a_block": s.u32(),
        "balances": s.vec(s.u128),
        "fee_recipient": dec_account(s),
        "account_id": dec_account(s),
        "yield_recipient": dec_account(s),
        "precision": s.u128(),
    }
    pool["_consumed"] = s.i
    pool["_total_len"] = len(b)
    return pool

def dec_system_account(hexstr):
    b = bytes.fromhex(hexstr[2:])
    s = Scale(b)
    return {"nonce": s.u32(), "consumers": s.u32(), "providers": s.u32(),
            "sufficients": s.u32(), "free": s.u128(), "reserved": s.u128(), "frozen": s.u128()}

def dec_orml_account(hexstr):
    b = bytes.fromhex(hexstr[2:])
    s = Scale(b)
    return {"free": s.u128(), "reserved": s.u128(), "frozen": s.u128()}

def main():
    out = {"fetched_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "endpoints_used": []}
    def note(url):
        if url not in out["endpoints_used"]: out["endpoints_used"].append(url)

    hdr, url = rpc_any("chain_getHeader", []); note(url)
    out["block"] = int(hdr["number"], 16)
    out["parent_hash"] = hdr["parentHash"]
    rv, url = rpc_any("state_getRuntimeVersion", []); note(url)
    out["runtime_version"] = rv
    chain, _ = rpc_any("system_chain", []); out["chain"] = chain

    acct = "23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9"
    pub = ss58_decode(acct)
    out["pallet_account"] = {"ss58": acct, "pubkey": pub.hex()}

    # raw hex dumps
    raw = {}
    def dump(key_hex):
        v, url = get_storage(key_hex); note(url)
        raw[key_hex] = v
        return v

    # System.Account (pallet acct)
    k = twox128(b"System") + twox128(b"Account") + blake2_128_concat(pub)
    v = dump("0x" + k.hex())
    out["system_account"] = dec_system_account(v) if v and v != "0x" else None

    # Tokens.Accounts enumeration (all currencies held)
    prefix = twox128(b"Tokens") + twox128(b"Accounts") + blake2_128_concat(pub)
    keys = []
    start = None
    while True:
        page, url = rpc_any("state_getKeysPaged", ["0x" + prefix.hex(), 100, start]); note(url)
        if not page: break
        keys.extend(page)
        if len(page) < 100: break
        start = page[-1]
    out["tokens_accounts_keys"] = keys
    toks = {}
    for kk in keys:
        v, url = get_storage(kk); note(url)
        if v and v != "0x":
            cid_hex = kk[2 + len(prefix) * 2 + 16:]  # skip suffix twox64(currency) -> wait: key = prefix + twox64(cid); tail after prefix is 8 bytes hasher + cid bytes
            tail = bytes.fromhex(kk[2:])[len(prefix):]
            cid_bytes = tail[8:]
            toks[cid_bytes.hex()] = dec_orml_account(v)
            raw[kk] = v
    out["tokens_accounts"] = toks

    # TotalIssuance for interesting currencies
    def cid_tw(hexbytes):
        b = bytes.fromhex(hexbytes)
        return twox128(b"Tokens") + twox128(b"TotalIssuance") + twox64(b)
    for name, cb in [("DOT", "0002"), ("LDOT", "0003"), ("TAP", "0004"), ("FA13", "050d00"),
                     ("PoolToken0", "0300000000"), ("PoolToken1", "0301000000"), ("PoolToken2", "0302000000")]:
        v = dump("0x" + cid_tw(cb).hex())
        out.setdefault("total_issuance", {})[name] = (int.from_bytes(bytes.fromhex(v[2:])[:16], 'little')
                                                     if v and v != "0x" else None)

    # StableAsset.PoolCount
    v = dump("0x" + (twox128(b"StableAsset") + twox128(b"PoolCount")).hex())
    out["pool_count"] = int.from_bytes(bytes.fromhex(v[2:])[:4], 'little') if v and v != "0x" else None

    # StableAsset.Pools[i]
    pools = {}
    if out["pool_count"]:
        for pid in range(out["pool_count"]):
            k = twox128(b"StableAsset") + twox128(b"Pools") + blake2_128_concat(pid.to_bytes(4, 'little'))
            v = dump("0x" + k.hex())
            if v and v != "0x":
                try:
                    pools[str(pid)] = dec_pool_info(v)
                except Exception as e:
                    pools[str(pid)] = {"decode_error": str(e), "raw": v}
    out["pools"] = pools

    # Homa exchange rate inputs (if storage present) - try known keys
    # modules/homa: TotalStakingCurrency / TotalVoidLiquid (names TBD) -> attempt list
    homa_attempts = {}
    for storage in ["TotalStakingCurrency", "TotalVoidLiquid", "ExchangeRate", "TotalStakingBonded"]:
        k = twox128(b"Homa") + twox128(storage.encode())
        v = dump("0x" + k.hex())
        if v and v != "0x":
            homa_attempts[storage] = {"raw": v, "u128": int.from_bytes(bytes.fromhex(v[2:])[:16], 'little')}
    out["homa_attempts"] = homa_attempts

    os.makedirs(os.path.dirname(os.path.abspath(__file__)), exist_ok=True)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), f"state-{out['block']}.json"), "w") as f:
        json.dump({"decoded": out, "raw_storage": raw}, f, indent=1)
    print(json.dumps(out, indent=1)[:6000])
    print("saved state-%s.json" % out["block"])

if __name__ == "__main__":
    main()
