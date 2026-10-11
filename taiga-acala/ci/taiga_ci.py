#!/usr/bin/env python3
"""Taiga Acala - L2 Phase-2 CI heavy job (read-only, public RPC only, no secrets).

Reproduces, at the CI run's latest block:
  1. live state: pallet account holdings, StableAsset pool 0, Homa rate inputs;
  2. the exact pallet gate math (D(stored) vs D(updated)) proving the pool is
     currently non-interactive (all mint/swap/redeem extrinsics revert);
  3. timeline check via archive state (last successful interaction block);
  4. latent `redeem_multi` imbalance-withdrawal economics;
  5. FULL enumeration of tDOT (StableAssetPoolToken(0)) holders from Tokens.Accounts.

Outputs (ci-out/): results.json, state.json, tdot-holders.csv, ci-run.log
"""
import json, hashlib, urllib.request, time, sys, os, csv

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

def ss58_encode(pub, prefix=10):
    payload = bytes([prefix]) + pub
    checksum = hashlib.blake2b(b"SS58PRE" + payload, digest_size=64).digest()[:2]
    data = payload + checksum
    num = int.from_bytes(data, 'big')
    out = ""
    while num > 0:
        num, rem = divmod(num, 58)
        out = B58[rem] + out
    pad = 0
    for c in data:
        if c == 0: pad += 1
        else: break
    return "1" * pad + out

ENDPOINTS = [
    "https://acala-rpc-0.aca-api.network",
    "https://acala-rpc-1.aca-api.network",
    "https://acala-rpc-2.aca-api.network",
    "https://acala-rpc-3.aca-api.network",
]
_rpc_state = {"url": None}

def rpc(method, params, retries=3):
    global _rpc_state
    urls = [_rpc_state["url"]] if _rpc_state["url"] else []
    urls += [u for u in ENDPOINTS if u not in urls]
    last = None
    for url in urls:
        for _ in range(retries):
            try:
                body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
                req = urllib.request.Request(url, data=body, headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    j = json.loads(r.read().decode())
                if "error" in j:
                    raise RuntimeError(j["error"])
                _rpc_state["url"] = url
                return j.get("result")
            except Exception as e:
                last = e; time.sleep(1.0)
    raise RuntimeError(f"{method} failed on all endpoints: {last}")

def http_json(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research)"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

# ---------------- storage keys ----------------
PALLET_ACCT_SS58 = "23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9"
PALLET_ACCT_PUB = bytes.fromhex("6d6f646c6e7574732f7374610000000000000000000000000000000000000000")
POOLS0_KEY = "0x" + (twox128(b"StableAsset") + twox128(b"Pools") + blake2_128_concat((0).to_bytes(4, 'little'))).hex()
TSB_KEY = "0x" + (twox128(b"Homa") + twox128(b"TotalStakingBonded")).hex()
TVL_KEY = "0x" + (twox128(b"Homa") + twox128(b"TotalVoidLiquid")).hex()
TSNOW_KEY = "0x" + (twox128(b"Timestamp") + twox128(b"Now")).hex()
LDOT_CID = bytes([0, 3])
DOT_CID = bytes([0, 2])
TDOT_CID = bytes([3, 0, 0, 0, 0])
def tokens_account_key(pub, cid):  # Tokens.Accounts double map
    return "0x" + (twox128(b"Tokens") + twox128(b"Accounts") + blake2_128_concat(pub) + twox64(cid) + cid).hex()
def total_issuance_key(cid):
    return "0x" + (twox128(b"Tokens") + twox128(b"TotalIssuance") + twox64(cid) + cid).hex()
TOKENS_ACCOUNTS_PREFIX = "0x" + (twox128(b"Tokens") + twox128(b"Accounts")).hex()
TDOT_SUFFIX = (twox64(TDOT_CID) + TDOT_CID).hex()

# ---------------- decoders ----------------
def u128(hexv):
    if not hexv or hexv == "0x": return None
    return int.from_bytes(bytes.fromhex(hexv[2:])[:16], 'little')

def parse_compact(b, i):
    first = b[i]; mode = first & 3
    if mode == 0: return first >> 2, i + 1
    if mode == 1: return int.from_bytes(b[i:i+2], 'little') >> 2, i + 2
    if mode == 2: return int.from_bytes(b[i:i+4], 'little') >> 2, i + 4
    return int.from_bytes(b[i:i+5], 'little') >> 2, i + 5

SYMBOLS = {0: "ACA", 1: "AUSD", 2: "DOT", 3: "LDOT", 4: "TAP"}

def dec_currency(b, i):
    v = b[i]; i += 1
    if v == 0:
        s = b[i]; i += 1
        return ("Token", SYMBOLS.get(s, s)), i
    if v == 1:  # DexShare - only used inside assets for DEX pairs, not here
        raise ValueError("DexShare not expected in pool assets")
    if v == 2: return ("Erc20", b[i:i+20].hex()), i + 20
    if v == 3: return ("StableAssetPoolToken", int.from_bytes(b[i:i+4], 'little')), i + 4
    if v == 4: return ("LiquidCrowdloan", int.from_bytes(b[i:i+4], 'little')), i + 4
    if v == 5: return ("ForeignAsset", int.from_bytes(b[i:i+2], 'little')), i + 2
    raise ValueError(f"unknown CurrencyId variant {v}")

def parse_pool_info(hexv):
    b = bytes.fromhex(hexv[2:]); i = 0
    pool_asset, i = dec_currency(b, i)
    na, i = parse_compact(b, i)
    assets = []
    for _ in range(na):
        a, i = dec_currency(b, i); assets.append(a)
    np_, i = parse_compact(b, i)
    precisions = [int.from_bytes(b[i+16*j:i+16*(j+1)], 'little') for j in range(np_)]; i += np_ * 16
    out = {"pool_asset": pool_asset, "assets": assets, "precisions": precisions}
    for name in ["mint_fee", "swap_fee", "redeem_fee", "total_supply", "a"]:
        out[name] = int.from_bytes(b[i:i+16], 'little'); i += 16
    out["a_block"] = int.from_bytes(b[i:i+4], 'little'); i += 4
    out["future_a"] = int.from_bytes(b[i:i+16], 'little'); i += 16
    out["future_a_block"] = int.from_bytes(b[i:i+4], 'little'); i += 4
    nb, i = parse_compact(b, i)
    out["balances"] = [int.from_bytes(b[i+16*j:i+16*(j+1)], 'little') for j in range(nb)]; i += nb * 16
    out["fee_recipient"] = b[i:i+32].hex(); i += 32
    out["account_id"] = b[i:i+32].hex(); i += 32
    out["yield_recipient"] = b[i:i+32].hex(); i += 32
    out["precision"] = int.from_bytes(b[i:i+16], 'little'); i += 16
    out["_consumed"] = i; out["_len"] = len(b)
    return out

def parse_orml_account(hexv):
    b = bytes.fromhex(hexv[2:])
    return {"free": int.from_bytes(b[0:16], 'little'),
            "reserved": int.from_bytes(b[16:32], 'little') if len(b) >= 32 else 0,
            "frozen": int.from_bytes(b[32:48], 'little') if len(b) >= 48 else 0,
            "raw_len": len(b)}

# ---------------- pallet math (mirrors nutsfinance stable-asset @ aa101e87) ----------------
def get_d(balances, a=3000, a_prec=100):
    n = len(balances); s = sum(balances)
    if s == 0: return 0
    ann = a
    for _ in balances: ann *= n  # ann = a * n^n
    d = s
    for _ in range(255):
        p_d = d
        for x in balances:
            p_d = p_d * d // (x * n)
        prev = d
        t1 = p_d * n
        t2 = (n + 1) * p_d
        t3 = (ann - a_prec) * d // a_prec + t2
        d = (ann * s // a_prec + t1) * d // t3
        if abs(d - prev) <= 1: break
    return d

def homa_rate(tsb, ldot_issuance, void_liquid):
    return tsb * 10**18 // (ldot_issuance + void_liquid)

def main():
    t0 = time.time()
    out = {"fetched_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "rpc_endpoints": ENDPOINTS}
    hdr = rpc("chain_getHeader", [])
    block = int(hdr["number"], 16)
    out["block"] = block
    out["chain"] = rpc("system_chain", [])
    rv = rpc("state_getRuntimeVersion", [])
    out["runtime"] = {"specName": rv.get("specName"), "specVersion": rv.get("specVersion"),
                      "transactionVersion": rv.get("transactionVersion")}
    print(f"[state] block={block} spec={rv.get('specVersion')}")

    state = {"block": block, "raw": {}}
    def get(key):
        v = rpc("state_getStorage", [key]); state["raw"][key] = v; return v

    # pool 0
    pool_raw = get(POOLS0_KEY)
    pool = parse_pool_info(pool_raw)
    assert pool["_consumed"] == pool["_len"], "PoolInfo parse mismatch"
    state["pool0"] = pool
    print(f"[state] pool0 assets={pool['assets']} balances={pool['balances']} supply={pool['total_supply']}")

    # pallet account holdings (enumerate Tokens.Accounts)
    acct_prefix = "0x" + (twox128(b"Tokens") + twox128(b"Accounts") + blake2_128_concat(PALLET_ACCT_PUB)).hex()
    acct_prefix_len = len(acct_prefix[2:]) // 2  # 80 bytes
    holdings = {}
    start = None
    while True:
        ks = rpc("state_getKeysPaged", [acct_prefix, 100, start]) or []
        for k in ks:
            v = get(k)
            if v and v != "0x":
                # key = prefix(16+32 account bytes) + twox64(cid) + cid
                kb = bytes.fromhex(k[2:])
                rem = kb[acct_prefix_len:]
                cid_bytes = rem[8:]
                holdings[cid_bytes.hex()] = parse_orml_account(v)
        if len(ks) < 100: break
        start = ks[-1]
    state["pallet_account_holdings"] = holdings
    print(f"[state] pallet account holdings: {json.dumps(holdings)}")

    # homa + issuance
    tsb = u128(get(TSB_KEY)); void = u128(get(TVL_KEY))
    ldot_iss = u128(get(total_issuance_key(LDOT_CID)))
    dot_iss = u128(get(total_issuance_key(DOT_CID)))
    tdot_iss = u128(get(total_issuance_key(TDOT_CID)))
    ts_now = u128(get(TSNOW_KEY))
    state["homa"] = {"total_staking_bonded": tsb, "total_void_liquid": void,
                     "ldot_total_issuance": ldot_iss, "dot_total_issuance": dot_iss,
                     "tdot_total_issuance": tdot_iss, "timestamp_ms": ts_now}
    print(f"[state] TSB={tsb/1e10:.6f} DOT | LDOT issuance={ldot_iss/1e10:.6f} | tDOT issuance={tdot_iss/1e10:.6f}")

    # ---------------- gate math ----------------
    rate = homa_rate(tsb, ldot_iss, void)
    raw_ldot = holdings.get("0003", {}).get("free", 0)
    raw_dot = holdings.get("0002", {}).get("free", 0)
    conv_ldot = rate * raw_ldot // 10**18
    d_stored = get_d(pool["balances"])
    d_updated = get_d([raw_dot, conv_ldot])
    supply = pool["total_supply"]
    # min rate for interactivity (bisect)
    lo, hi = 0.0, 2.0
    for _ in range(120):
        mid = (lo + hi) / 2
        if get_d([raw_dot, int(mid * raw_ldot)]) >= supply: hi = mid
        else: lo = mid
    gate = {
        "homa_rate_raw": str(rate), "homa_rate": rate / 1e18,
        "converted_ldot_balance": str(conv_ldot),
        "d_stored_balances": str(d_stored), "d_updated_balances": str(d_updated),
        "stored_total_supply": str(supply),
        "d_stored_equals_supply": d_stored == supply,
        "gate_new_d_ge_old_d": d_updated >= supply,
        "deficit_raw": str(supply - d_updated) if d_updated < supply else "0",
        "deficit_dot_equiv": (supply - d_updated) / 1e10 if d_updated < supply else 0.0,
        "min_rate_interactive": hi, "gap_pct": (hi / (rate / 1e18) - 1) * 100 if rate else None,
        "interpretation": ("Pool is NON-INTERACTIVE: collect_yield() requires D(updated)>=total_supply; "
                           "every mint/swap/redeem_* extrinsic reverts with InvalidPoolValue."),
    }
    out["gate"] = gate
    print(f"[gate] rate={rate/1e18:.9f} D_updated={d_updated/1e10:.2f} supply={supply/1e10:.2f} "
          f"deficit={gate['deficit_dot_equiv']:.2f} DOT-eq | interactive={d_updated >= supply}")

    # ---------------- latent redeem_multi concavity ----------------
    latent = []
    fee, fp = 30_000_000, 10_000_000_000
    for x in [10**13, 10**14, 5*10**14, 10**15, 2*10**15]:
        nb = [pool["balances"][0], pool["balances"][1] - x]
        if nb[1] < 0: continue
        dd = d_stored - get_d(nb)
        pay = dd * fp // (fp - fee)
        latent.append({"x_ldot_eq": x / 1e10, "d_drop": dd / 1e10, "pay_pooltoken": pay / 1e10,
                       "ratio": pay / x, "profit_dot_eq": (x - pay) / 1e10})
    out["latent_redeem_multi"] = {
        "note": "only reachable if/when the gate clears; computed on stored balances (max-imbalance state)",
        "rows": latent,
    }

    # ---------------- archive timeline ----------------
    try:
        tl = {}
        for n in [12048433, 12048434, block]:
            h = rpc("chain_getBlockHash", [n])
            if not h: continue
            pv = rpc("state_getStorage", [POOLS0_KEY, h])
            p = parse_pool_info(pv) if pv and pv != "0x" else None
            ts = u128(rpc("state_getStorage", [TSNOW_KEY, h]))
            tl[n] = {"utc": time.strftime('%Y-%m-%d %H:%M', time.gmtime(ts/1000)) if ts else None,
                     "total_supply": p["total_supply"] if p else None,
                     "balances": p["balances"] if p else None}
        out["timeline"] = tl
        print(f"[timeline] {json.dumps(tl)}")
    except Exception as e:
        out["timeline"] = f"ERR: {e}"

    # ---------------- tDOT holder scan ----------------
    print("[scan] enumerating Tokens.Accounts for tDOT holders ...")
    holder_keys = []
    start = None
    pages = 0
    total_keys = 0
    max_pages = int(os.environ.get("TAIGA_MAX_PAGES", "4000"))
    while pages < max_pages:
        ks = rpc("state_getKeysPaged", [TOKENS_ACCOUNTS_PREFIX, 1000, start]) or []
        if not ks: break
        pages += 1
        total_keys += len(ks)
        for k in ks:
            if k.endswith(TDOT_SUFFIX):
                holder_keys.append(k)
        if pages % 20 == 0:
            print(f"[scan] pages={pages} keys={total_keys} tDOT-holder-entries={len(holder_keys)} "
                  f"({time.time()-t0:.0f}s)")
        if len(ks) < 1000: break
        start = ks[-1]
    print(f"[scan] done: {total_keys} keys scanned, {len(holder_keys)} tDOT entries, {time.time()-t0:.0f}s")

    holders = []
    BATCH = 200
    for i in range(0, len(holder_keys), BATCH):
        batch = holder_keys[i:i+BATCH]
        changes = None
        try:
            res = rpc("state_queryStorageAt", [batch])
            changes = res[0]["changes"] if res else []
        except Exception:
            changes = None
        if changes is None:
            # fallback: individual reads
            changes = []
            for k in batch:
                try:
                    changes.append([k, rpc("state_getStorage", [k])])
                except Exception:
                    pass
        for k, v in changes:
            if not v or v == "0x": continue
            kb = bytes.fromhex(k[2:])
            # key = twox128(Tokens)+twox128(Accounts) (32B) + blake2_128_concat(account) (16+32B) + twox64(cid)+cid
            acct = kb[32 + 16:32 + 16 + 32]
            acc = parse_orml_account(v)
            holders.append({"pub": acct.hex(), "ss58": ss58_encode(acct), "free": acc["free"]})
    holders.sort(key=lambda h: -h["free"])
    total = sum(h["free"] for h in holders)
    out["tdot_holders"] = {
        "entries": len(holders),
        "total_free_raw": str(total),
        "total_free": total / 1e10,
        "issuance_raw": str(tdot_iss),
        "issuance": tdot_iss / 1e10 if tdot_iss else None,
        "coverage_pct": (total / tdot_iss * 100) if tdot_iss else None,
        "top": [{"ss58": h["ss58"], "free": h["free"] / 1e10} for h in holders[:25]],
    }
    print(f"[scan] tDOT holders={len(holders)} total={total/1e10:.4f} tDOT "
          f"(issuance {tdot_iss/1e10:.4f})")
    for h in out["tdot_holders"]["top"][:10]:
        print(f"    {h['ss58']} {h['free']:.6f} tDOT")

    # ---------------- prices (public APIs) ----------------
    prices = {}
    try:
        d = http_json("https://coins.llama.fi/prices/current/coingecko:polkadot")
        prices["dot_usd_llama"] = d.get("coins", {}).get("coingecko:polkadot", {}).get("price")
    except Exception as e:
        prices["dot_usd_llama"] = f"ERR:{e}"
    try:
        d = http_json("https://api.coingecko.com/api/v3/simple/price?ids=polkadot,liquid-staking-dot&vs_currencies=usd")
        prices["dot_usd_cg"] = d.get("polkadot", {}).get("usd")
        prices["ldot_usd_cg"] = d.get("liquid-staking-dot", {}).get("usd")
    except Exception as e:
        prices["cg"] = f"ERR:{e}"
    out["prices"] = prices

    # ---------------- USD valuation ----------------
    dot_usd = prices.get("dot_usd_llama") or prices.get("dot_usd_cg") or 1.236
    if isinstance(dot_usd, str): dot_usd = 1.236
    ldot_usd_cg = prices.get("ldot_usd_cg")
    if isinstance(ldot_usd_cg, str): ldot_usd_cg = None
    dot_amt = raw_dot / 1e10
    ldot_amt = raw_ldot / 1e10
    ldot_fundamental = rate / 1e18 * dot_usd
    val = {
        "dot_price_usd": dot_usd,
        "dot_amount": dot_amt, "dot_usd": dot_amt * dot_usd,
        "ldot_amount": ldot_amt,
        "ldot_fundamental_usd_per": ldot_fundamental,
        "ldot_usd_fundamental": ldot_amt * ldot_fundamental,
        "ldot_usd_market_cg": (ldot_amt * ldot_usd_cg) if ldot_usd_cg else None,
        "total_usd_fundamental": dot_amt * dot_usd + ldot_amt * ldot_fundamental,
        "total_usd_market_cg": (dot_amt * dot_usd + ldot_amt * ldot_usd_cg) if ldot_usd_cg else None,
        "pink_note": "ForeignAsset(13) PINK held by pallet account, unpriced/illiquid (excluded)",
    }
    out["valuation"] = val
    print(f"[value] DOT={dot_amt:.4f}@${dot_usd}  LDOT={ldot_amt:.4f} (fund ${ldot_fundamental:.4f}) "
          f"total_fundamental=${val['total_usd_fundamental']:.2f}")

    out["summary_line"] = (f"block {block}: gate {'PASS' if gate['gate_new_d_ge_old_d'] else 'FAIL'} "
                           f"(deficit {gate['deficit_dot_equiv']:.2f} DOT-eq); "
                           f"E-U=0; stuck value ~${val['total_usd_market_cg'] or val['total_usd_fundamental']:.0f}")

    os.makedirs("ci-out", exist_ok=True)
    with open("ci-out/results.json", "w") as f:
        json.dump(out, f, indent=1)
    with open("ci-out/state.json", "w") as f:
        json.dump(state, f, indent=1)
    with open("ci-out/tdot-holders.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(["ss58", "pubkey_hex", "free_raw", "free_tdot"])
        for h in holders:
            w.writerow([h["ss58"], h["pub"], h["free"], h["free"] / 1e10])
    print(f"[done] wrote ci-out/ results ({time.time()-t0:.0f}s)")

if __name__ == "__main__":
    main()
