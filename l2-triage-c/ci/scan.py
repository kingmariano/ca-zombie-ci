#!/usr/bin/env python3
"""
L2-Triage-C live custody scanner (read-only).

Queries chain-native public endpoints for live balances of each protocol's core
custody accounts/contracts. Outputs ci-out/results.json (+ results.csv).

NEVER prints or writes keyed RPC URLs: any env-derived secret is redacted from
all logs and outputs.
"""
import base64
import hashlib
import json
import os
import socket
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)          # l2-triage-c/
OUTDIR = os.path.join(ROOT, "ci-out")
os.makedirs(OUTDIR, exist_ok=True)

SECRETS = [v for k, v in os.environ.items()
           if any(t in k for t in ("KEY", "TOKEN", "SECRET", "RPC_URL")) and v and len(v) > 8]

def redact(s):
    s = str(s)
    for sec in SECRETS:
        if sec in s:
            s = s.replace(sec, "<redacted>")
    return s

LOG = []

def log(*a):
    line = redact(" ".join(str(x) for x in a))
    LOG.append(line)
    print(line, flush=True)

def http(url, body=None, timeout=40, retries=2, headers=None, method=None):
    hdrs = {"User-Agent": "Mozilla/5.0 (l2-triage)", "Accept": "application/json"}
    if headers:
        hdrs.update(headers)
    data = None
    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        hdrs.setdefault("Content-Type", "application/json")
    last = None
    for i in range(retries + 1):
        try:
            req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                raw = r.read()
            try:
                return json.loads(raw.decode("utf-8", "replace"))
            except Exception:
                return raw.decode("utf-8", "replace")
        except Exception as e:
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(redact(f"{type(last).__name__}: {last}"))

def http_text(url, timeout=40, retries=1):
    return http(url, timeout=timeout, retries=retries)

# ---------------------------------------------------------------- selectors
# keccak256(name) & (2**250-1)  (Starknet entry point selectors)
STARKNET_SEL = {
    "get_all_pairs": "0x3e415d1aae9ddb9b1ffdb1f3bb6591b593e0a09748f635cdd067a74aba6f671",
    "token0": "0xad5d3ec16e143a33da68c00099116ef328a882b65607bec5b2431267934a20",
    "token1": "0x3610e8e1835afecdd154863369b91f55612defc17933f83f4425533c435a248",
    "get_reserves": "0x3cb0e1486e633fbe3e2fafe8aedf12b70ca1860e7467ddb75a17858cde39312",
    "allPairsLength": "0x39c628dd69d8a2f0773ac569310eb1e4729a6d4c626c255ee264d3f0bb265c4",
    "allPairs": "0x322330b99043a35eb61a21ff439b5d8fb60c05f689cb96da4eb9baf0ddda6a7",
    "getReserves": "0x3c388f7eb137a89061c6f0b6e78bae453202258b0b3c419f8dd9814a547d406",
    "decimals": "0x4c4fb1ab068f6039d5780c68dd0fa2f8742cceb3426d19667778ca7f3518a9",
    "symbol": "0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4",
}
# 4-byte EVM selectors
EV = {
    "activePool()": "0x7f7dde4a",
    "defaultPool()": "0x3cc74225",
    "balanceOf(address)": "0x70a08231",
    "getCash()": "0x3b1d21a2",
    "getAllMarkets()": "0xb0772d0b",
    "underlying()": "0x6f307dc3",
    "totalBorrows()": "0x47bd3718",
    "getReserves()": "0x0902f1ac",
    "decimals()": "0x313ce567",
}

# ---------------------------------------------------------------- price keys
PRICE_KEY_MAP = {
    "native:bitcoin": "coingecko:bitcoin",
    "native:bitcoincash": "coingecko:bitcoin-cash",
    "native:ergo": "coingecko:ergo",
    "native:hbar": "coingecko:hedera-hashgraph",
    "native:fil": "coingecko:filecoin",
    "native:ada": "coingecko:cardano",
    "native:dot": "coingecko:polkadot",
    "native:ldot": "coingecko:liquid-staking-dot",
    "native:xrd": "coingecko:radix",
    "native:sol": "coingecko:solana",
    "native:inj": "injective:inj",
    "native:osmo": "osmosis:uosmo",
    "native:scrt": "coingecko:secret",
    "native:icx": "coingecko:icon",
    "native:aca": "coingecko:acala",
    "native:eth": "coingecko:ethereum",
    "native:usdc": "coingecko:usd-coin",
    "native:usdt": "coingecko:tether",
}

def price_of(tokens_usd_needed, price_keys):
    """Fetch prices for a set of DefiLlama coins-api keys (batched)."""
    prices = {}
    keys = sorted(set(price_keys))
    for i in range(0, len(keys), 40):
        chunk = keys[i:i + 40]
        try:
            enc = ",".join(urllib.parse.quote(k, safe="") for k in chunk)
            r = http("https://coins.llama.fi/prices/current/" + enc, timeout=30)
            for k, v in (r.get("coins", {}) if isinstance(r, dict) else {}).items():
                prices[k] = v.get("price")
        except Exception as e:
            log("  price batch failed:", e)
    return prices

# ---------------------------------------------------------------- per-chain RPC
SUI_ENDPOINTS = ["https://sui-rpc.publicnode.com", "https://sui-mainnet-endpoint.blockvision.org",
                 "https://fullnode.mainnet.sui.io:443"]

def sui_rpc(method, params, url=None, _tries=4):
    last = None
    urls = [url] if url else SUI_ENDPOINTS
    for attempt in range(_tries):
        for u in urls:
            try:
                r = http(u, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=45, retries=0)
                if "error" in r:
                    last = r["error"]
                    if isinstance(last, dict) and last.get("code") == -32601:
                        continue
                    continue
                return r.get("result")
            except Exception as e:
                last = e
                continue
        time.sleep(2.0 * (attempt + 1))
    raise RuntimeError(redact(str(last)[:200]))

def starknet_rpc(method, params, urls=None):
    urls = urls or ["https://api.cartridge.gg/x/starknet/mainnet",
                    "https://starknet.drpc.org", "https://1rpc.io/starknet"]
    last = None
    for u in urls:
        try:
            r = http(u, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=60)
            if "error" in r and r["error"]:
                last = r["error"]
                continue
            return r.get("result")
        except Exception as e:
            last = e
    raise RuntimeError(redact(f"starknet {method} failed: {last}"))

def starknet_call(addr, selector, calldata=None, block="latest"):
    return starknet_rpc("starknet_call", {"request": {
        "contract_address": addr, "entry_point_selector": selector,
        "calldata": calldata or []}, "block_id": block})

def starknet_batch(calls, chunk=120):
    """calls: list of (addr, selector, calldata). Returns list of ret arrays."""
    out = []
    urls = ["https://api.cartridge.gg/x/starknet/mainnet", "https://starknet.drpc.org"]
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        batch = [{"jsonrpc": "2.0", "id": j, "method": "starknet_call", "params": {
            "request": {"contract_address": c[0], "entry_point_selector": c[1], "calldata": c[2] or []},
            "block_id": "latest"}} for j, c in enumerate(part)]
        done = False
        for attempt in range(3):
            for u in urls:
                try:
                    r = http(u, batch, timeout=90)
                    if isinstance(r, list):
                        byid = {x.get("id"): x for x in r}
                        for j in range(len(part)):
                            x = byid.get(j, {})
                            out.append(x.get("result") if "result" in x else None)
                        done = True
                        break
                except Exception:
                    continue
            if done:
                break
            time.sleep(2.0 * (attempt + 1))
        if not done:
            out.extend([None] * len(part))
        time.sleep(0.8)
    return out

def cosmos_lcd_smart(lcd, contract, query, timeout=30):
    b = base64.b64encode(json.dumps(query).encode()).decode()
    r = http(f"{lcd}/cosmwasm/wasm/v1/contract/{contract}/smart/{b}", timeout=timeout)
    if isinstance(r, dict) and "data" in r:
        return r["data"]
    return r

def evm_rpc(url, method, params):
    r = http(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    if "error" in r and r["error"]:
        raise RuntimeError(str(r["error"])[:160])
    return r.get("result")

# ---------------------------------------------------------------- xxhash (pure py)
_M64 = (1 << 64) - 1
_P1, _P2, _P3, _P4, _P5 = 0x9E3779B185EBCA87, 0xC2B2AE3D27D4EB4F, 0x165667B19E3779F9, 0x85EBCA77C2B2AE63, 0x27D4EB2F165667C5

def _rotl(x, r):
    return ((x << r) | (x >> (64 - r))) & _M64

def xxh64(data, seed=0):
    n, i = len(data), 0
    if n >= 32:
        v1, v2, v3, v4 = (seed + _P1 + _P2) & _M64, (seed + _P2) & _M64, seed & _M64, (seed - _P1) & _M64
        vs = [v1, v2, v3, v4]
        while i + 32 <= n:
            for vi in range(4):
                k = int.from_bytes(data[i:i + 8], "little"); i += 8
                vs[vi] = (_rotl((vs[vi] + k * _P2) & _M64, 31) * _P1) & _M64
        h = (_rotl(vs[0], 1) + _rotl(vs[1], 7) + _rotl(vs[2], 12) + _rotl(vs[3], 18)) & _M64
        for v in vs:
            h = ((h ^ (_rotl((v * _P2) & _M64, 31) * _P1) & _M64) * _P1 + _P4) & _M64
    else:
        h = (seed + _P5) & _M64
    h = (h + n) & _M64
    while i + 8 <= n:
        k = int.from_bytes(data[i:i + 8], "little"); i += 8
        h = (_rotl((h ^ (_rotl((k * _P2) & _M64, 31) * _P1) & _M64), 27) * _P1 + _P4) & _M64
    if i + 4 <= n:
        k = int.from_bytes(data[i:i + 4], "little"); i += 4
        h = (_rotl((h ^ (k * _P1) & _M64), 23) * _P2 + _P3) & _M64
    while i < n:
        h = (_rotl((h ^ (data[i] * _P5) & _M64), 11) * _P1) & _M64; i += 1
    h ^= h >> 33; h = (h * _P2) & _M64; h ^= h >> 29; h = (h * _P3) & _M64; h ^= h >> 32
    return h

assert xxh64(b"") == 0xEF46DB3751D8E999

def twox64(b): return xxh64(b, 0).to_bytes(8, "little")
def twox128(b): return xxh64(b, 0).to_bytes(8, "little") + xxh64(b, 1).to_bytes(8, "little")
def blake2_128_concat(b): return hashlib.blake2b(b, digest_size=16).digest() + b

_B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58decode(s):
    num = 0
    for c in s:
        num = num * 58 + _B58.index(c)
    full = num.to_bytes((num.bit_length() + 7) // 8, "big")
    return b"\x00" * (len(s) - len(s.lstrip("1"))) + full

def b58encode(b):
    num = int.from_bytes(b, "big")
    out = ""
    while num:
        num, r = divmod(num, 58)
        out = _B58[r] + out
    return "1" * (len(b) - len(b.lstrip(b"\x00"))) + (out or "")

def ss58_decode(addr):
    raw = b58decode(addr)
    return raw[1:-2]

def substrate_rpc(url, method, params):
    return http(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=45).get("result")

# ================================================================ collectors
RESULTS = []

def add(slug, protocol, chain, **kw):
    row = {"slug": slug, "protocol": protocol, "chain": chain, "status": "UNKNOWN",
           "live_usd": None, "confidence": "low", "custody": [], "tokens": {},
           "token_decimals": {}, "evidence": {}, "errors": [], "notes": []}
    row.update(kw)
    RESULTS.append(row)
    return row

def llama_now(slug):
    try:
        r = http(f"https://api.llama.fi/protocol/{slug}", timeout=30)
        if isinstance(r, dict):
            return {"currentChainTvls": r.get("currentChainTvls"),
                    "last_tvl_date": (r.get("tvl") or [{}])[-1].get("date")}
    except Exception as e:
        return {"error": redact(e)}
    return {}

# ---------- 1. Fiamma (Bitcoin bridge) ----------
def c_fiamma():
    row = add("fiamma", "Fiamma", "Bitcoin")
    row["custody"] = ["Fiamma BitVM2 bridge federation (BTC custody; deposit address not published in adapter)"]
    try:
        r = http("https://bridge-api.fiammachain.io", {"jsonrpc": "2.0", "id": 1,
                 "method": "frontend_queryBridgeTVL", "params": {}}, timeout=20, retries=1)
        row["evidence"]["bridge_api"] = r
    except Exception as e:
        row["errors"].append(f"bridge-api.fiammachain.io dead: {e}")
    for u in ["https://fiammachain.io/api/bridge/tvl", "https://api.fiammachain.io/bridge/tvl"]:
        try:
            row["evidence"].setdefault("alt_api", {})[u] = str(http_text(u, timeout=15))[:200]
        except Exception as e:
            row["evidence"].setdefault("alt_api", {})[u] = redact(e)
    row["notes"].append("DefiLlama adapter source = bridge-api.fiammachain.io (last good read 2026-03-18 per llama)")
    row["status"] = "UNREACHABLE"
    row["confidence"] = "medium"

# ---------- 2. BlueMove DEX (Sui) ----------
def sui_all_dynamic_fields(acct, limit=50):
    out, cursor = [], None
    while True:
        d = sui_rpc("suix_getDynamicFields", [acct, cursor, limit])
        out.extend(d.get("data", []))
        if not d.get("hasNextPage"):
            break
        cursor = d.get("nextCursor")
    return out

def sui_objects(ids, chunk=50, log=None):
    objs = []
    for i in range(0, len(ids), chunk):
        part = ids[i:i + chunk]
        got = None
        for attempt in range(3):
            try:
                r = sui_rpc("sui_multiGetObjects", [part, {"showContent": True, "showType": True}])
            except Exception:
                r = None
            if r and sum(1 for o in r if o and (o.get("content") or {}).get("fields")) >= max(1, len(part) // 2):
                got = r
                break
            time.sleep(1.0 * (attempt + 1))
        if got is None:
            # per-object fallback for this chunk
            got = []
            for oid in part:
                try:
                    single = sui_rpc("sui_getObject", [oid, {"showContent": True, "showType": True}])
                    got.append((single or {}).get("data"))
                except Exception:
                    got.append(None)
        objs.extend(got or [])
        time.sleep(0.15)
    return objs

def parse_sui_pool_type(t):
    # ...::swap::Pool<A,B> (JSON-RPC uses ", ", GraphQL uses ",")
    try:
        inner = t.split("<", 1)[1].rstrip(">")
        a, b = inner.split(",", 1)
        return a.strip(), b.strip()
    except Exception:
        return None, None

def sui_graphql_dynamic_fields(parent, max_pages=450):
    """Paginate dynamicFields via Sui GraphQL; returns list of {type_repr, json}."""
    out = []
    cursor = None
    q = """
query($addr: SuiAddress!, $after: String) {
  object(address: $addr) {
    dynamicFields(first: 50, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { value { ... on MoveObject { address contents { type { repr } json } } } }
    }
  }
}
"""
    for _ in range(max_pages):
        try:
            r = http("https://graphql.mainnet.sui.io/graphql",
                     {"query": q, "variables": {"addr": parent, "after": cursor}}, timeout=60, retries=2)
        except Exception:
            time.sleep(2)
            continue
        obj = (((r or {}).get("data") or {}).get("object") or {})
        df = obj.get("dynamicFields") or {}
        nodes = df.get("nodes") or []
        for n in nodes:
            v = (n or {}).get("value") or {}
            c = v.get("contents") or {}
            t = (c.get("type") or {}).get("repr") or ""
            j = c.get("json")
            if j is not None:
                out.append({"type": t, "json": j})
        pi = df.get("pageInfo") or {}
        if not pi.get("hasNextPage"):
            break
        cursor = pi.get("endCursor")
        time.sleep(0.1)
    return out

def sui_norm_addr(a):
    try:
        return "0x" + format(int(a.split("::")[0], 16), "x") + "::" + "::".join(a.split("::")[1:])
    except Exception:
        return a

def c_bluemove():
    row = add("bluemove-dex", "BlueMove DEX", "Sui")
    acct_amm = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
    acct_stable = "0x5a7eca40df453efe6bb1feae99e5b8fc072d1252cbd1979eb187d625dc9b47c9"
    row["custody"] = [acct_amm, acct_stable]
    try:
        fields = sui_graphql_dynamic_fields(acct_amm)
        row["evidence"]["amm_fields"] = len(fields)
        tokens = {}
        n_pools = 0
        for f in fields:
            t = f["type"]; j = f["json"]
            if "::swap::Pool<" in t and "reserve_x" in j and "reserve_y" in j:
                t0, t1 = parse_sui_pool_type(t)
                if t0: tokens["sui:" + sui_norm_addr(t0)] = tokens.get("sui:" + sui_norm_addr(t0), 0) + int(j["reserve_x"])
                if t1: tokens["sui:" + sui_norm_addr(t1)] = tokens.get("sui:" + sui_norm_addr(t1), 0) + int(j["reserve_y"])
                n_pools += 1
        row["evidence"]["amm_pools_parsed"] = n_pools
        try:
            sfields = sui_graphql_dynamic_fields(acct_stable)
            row["evidence"]["stable_fields"] = len(sfields)
            n_st = 0
            for f in sfields:
                t = f["type"]; j = f["json"]
                if "Stable_Pool" in t and "token_x" in j and "token_y" in j:
                    t0, t1 = parse_sui_pool_type(t)
                    if t0: tokens["sui:" + sui_norm_addr(t0)] = tokens.get("sui:" + sui_norm_addr(t0), 0) + int(j["token_x"])
                    if t1: tokens["sui:" + sui_norm_addr(t1)] = tokens.get("sui:" + sui_norm_addr(t1), 0) + int(j["token_y"])
                    n_st += 1
            row["evidence"]["stable_pools_parsed"] = n_st
        except Exception as e:
            row["errors"].append("stable: " + redact(e))
        # decimals: curated majors + top raw-amount tokens (metadata permitting)
        decs = {}
        majors = [
            "sui:0x2::sui::SUI",
            "sui:0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
            "sui:0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN",
            "sui:0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade587435961f5450fe45::coin::COIN",
            "sui:0x06864a6f921804860930db6ddbe2e16acdf8504495ea7481637a1c8b9a8fe54b::cetus::CETUS",
            "sui:0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
            "sui:0xa99b8952d4f7d947ea77fe0ecdcc9e5fc0bcab2841d6e2a5aa00c3044e5544b5::navx::NAVX",
        ]
        top_tokens = sorted(tokens.keys(), key=lambda t: -tokens[t])[:40]
        for t in majors + top_tokens:
            if t in decs or t not in tokens:
                continue
            try:
                md = sui_rpc("suix_getCoinMetadata", [t.split("sui:", 1)[1]])
                if md and md.get("decimals") is not None:
                    decs[t] = int(md["decimals"])
            except Exception:
                pass
        row["token_decimals"] = decs
        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "medium"
        row["notes"].append("reserves read via Sui GraphQL dynamicFields (content-bearing); decimals from coin metadata")
    except Exception as e:
        row["errors"].append(redact(e))
        row["status"] = "UNREACHABLE"

# ---------- 3/4. Starknet DEXes ----------
def starknet_pair_tvl(row, pairs, reserves_abi="jediswap"):
    res_sel = STARKNET_SEL["get_reserves"] if reserves_abi == "jediswap" else STARKNET_SEL["getReserves"]
    calls = []
    for p in pairs:
        calls.append((p, STARKNET_SEL["token0"], []))
        calls.append((p, STARKNET_SEL["token1"], []))
        calls.append((p, res_sel, []))
    rets = starknet_batch(calls)
    tokens = {}
    npairs = 0
    for i in range(0, len(pairs)):
        try:
            t0 = rets[3 * i]; t1 = rets[3 * i + 1]; rr = rets[3 * i + 2]
            if not t0 or not t1 or not rr:
                continue
            t0 = hex(int(t0[0], 16)); t1 = hex(int(t1[0], 16))
            if reserves_abi == "jediswap":
                # empirical (balanceOf-verified): [r0_low, r0_high, r1_low, r1_high, ts]
                r0 = int(rr[0], 16) + (int(rr[1], 16) << 128)
                r1 = int(rr[2], 16) + (int(rr[3], 16) << 128)
            else:
                # 10kswap: [r0, r1, ts]
                r0 = int(rr[0], 16); r1 = int(rr[1], 16)
            tokens[f"starknet:{t0}"] = tokens.get(f"starknet:{t0}", 0) + r0
            tokens[f"starknet:{t1}"] = tokens.get(f"starknet:{t1}", 0) + r1
            npairs += 1
        except Exception:
            continue
    row["evidence"]["pairs_parsed"] = npairs
    row["tokens"] = tokens
    # token decimals + symbols (batched; needed for USD conversion)
    tks = sorted({t.split(":", 1)[1] for t in tokens})
    decs, syms = {}, {}
    dcalls = [(t, STARKNET_SEL["decimals"], []) for t in tks] + [(t, STARKNET_SEL["symbol"], []) for t in tks]
    dret = starknet_batch(dcalls)
    for i, t in enumerate(tks):
        try:
            if dret[i]:
                decs[f"starknet:{t}"] = int(dret[i][0], 16)
            if len(dret) > len(tks) + i and dret[len(tks) + i]:
                h = dret[len(tks) + i][0]
                try:
                    syms[t] = bytes.fromhex(h[2:]).decode("utf-8", "replace").rstrip("\x00")
                except Exception:
                    pass
        except Exception:
            continue
    row["token_decimals"] = decs
    row["evidence"]["symbols"] = syms
    row["evidence"]["decimals_fetched"] = len(decs)

def c_jediswap():
    row = add("jediswap-v1", "JediSwap V1", "Starknet")
    factory = "0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
    row["custody"] = [f"factory {factory} + all pair contracts (reserves)"]
    try:
        ret = starknet_call(factory, STARKNET_SEL["get_all_pairs"])
        pairs = [hex(int(x, 16)) for x in ret[1:]]
        row["evidence"]["pairs"] = len(pairs)
        starknet_pair_tvl(row, pairs, "jediswap")
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in row["tokens"].values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

def c_10kswap():
    row = add("10kswap", "10KSwap", "Starknet")
    factory = "0x1c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2"
    row["custody"] = [f"factory {factory} + all pair contracts (reserves)"]
    try:
        ret = starknet_call(factory, STARKNET_SEL["allPairsLength"])
        if len(ret) >= 2:
            n = int(ret[0], 16) + (int(ret[1], 16) << 128)
        else:
            n = int(ret[0], 16)
        row["evidence"]["pair_count"] = n
        pcalls = [(factory, STARKNET_SEL["allPairs"], [hex(i)]) for i in range(0, n)]
        pret = starknet_batch(pcalls)
        pairs = []
        for r in pret:
            if r:
                pairs.append(hex(int(r[0], 16)))
        starknet_pair_tvl(row, pairs, "10kswap")
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in row["tokens"].values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 5. SFT Protocol (Filecoin) ----------
def c_sft():
    row = add("sft-protocol", "SFT Protocol", "Filecoin")
    pool = "0x147122D1EBdA76E4910ccdC53aEb6a58605Eb58E"
    row["custody"] = [pool, "(+ active miner actors from ww8.sftproject.io dashboard API — source dead)"]
    try:
        bal = evm_rpc("https://api.node.glif.io/rpc/v1", "eth_getBalance", [pool, "latest"])
        fil = int(bal, 16) / 1e18
        row["tokens"] = {"native:fil": fil}
        row["evidence"]["pool_fil"] = fil
        row["evidence"]["pool"] = pool
    except Exception as e:
        row["errors"].append(redact(e))
    for u in ["https://ww8.sftproject.io/api/c/api/v1/public/dashboard/info",
              "https://api.sftproject.io/api/c/api/v1/public/dashboard/info",
              "https://www.sftproject.io/api/c/api/v1/public/dashboard/info"]:
        try:
            r = http_text(u, timeout=15)
            row["evidence"]["dashboard_api"] = {"url": u, "sample": str(r)[:160]}
            break
        except Exception as e:
            row["errors"].append(f"{u}: {redact(e)}")
    row["status"] = "LIVE-FUNDED" if row.get("tokens") else "UNREACHABLE"
    row["confidence"] = "medium"

# ---------- 6. Armada (Solana) ----------
def sol_endpoints():
    eps = []
    ak = os.environ.get("ALCHEMY_API_KEY")
    if ak:
        eps.append(f"https://solana-mainnet.g.alchemy.com/v2/{ak}")
    eps += ["https://api.mainnet-beta.solana.com", "https://solana-rpc.publicnode.com"]
    return eps

def sol_rpc(method, params, timeout=60):
    last = None
    for u in sol_endpoints():
        try:
            r = http(u, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=timeout)
            if "error" in r and r["error"]:
                last = r["error"]; continue
            return r.get("result")
        except Exception as e:
            last = e
    raise RuntimeError(redact(f"solana {method}: {last}"))

def spl_amount(data_b64):
    b = base64.b64decode(data_b64)
    return int.from_bytes(b[64:72], "little")

def sol_mint_decimals(mints, top=60, raw_amounts=None):
    mints = list(mints)
    if raw_amounts:
        mints = sorted(mints, key=lambda m: -(raw_amounts.get(m, 0)))[:top]
    decs = {}
    for i in range(0, len(mints), 100):
        chunk = mints[i:i + 100]
        try:
            r = sol_rpc("getMultipleAccounts", [chunk, {"encoding": "jsonParsed"}], timeout=60)
            for j, acct in enumerate(r.get("value", []) if isinstance(r, dict) else (r or [])):
                try:
                    decs[chunk[j]] = int(acct["data"]["parsed"]["info"]["decimals"])
                except Exception:
                    pass
        except Exception:
            pass
    return decs

def c_armada():
    row = add("armada", "Armada", "Solana")
    program = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
    row["custody"] = [f"program {program} CLP vaults + token vaults"]
    try:
        accs = None
        for seed in ("account:ClpVault", "account:clpVault", "account:CLPVault"):
            disc = hashlib.sha256(seed.encode()).digest()[:8]
            accs = sol_rpc("getProgramAccounts", [program, {
                "encoding": "base64",
                "filters": [{"memcmp": {"offset": 0, "bytes": b58encode(disc)}}],
                "dataSlice": {"offset": 120, "length": 128}}], timeout=90)
            if accs:
                row["evidence"]["discriminator_seed"] = seed
                break
        row["evidence"]["vaults"] = len(accs or [])
        vault_atas, mints = [], {}
        for a in accs or []:
            b = base64.b64decode(a["account"]["data"][0])
            mintA = b58encode(b[0:32]); vaultA = b58encode(b[32:64])
            mintB = b58encode(b[64:96]); vaultB = b58encode(b[96:128])
            vault_atas += [vaultA, vaultB]
            mints[vaultA] = mintA; mints[vaultB] = mintB
        tokens = {}
        if vault_atas:
            for i in range(0, len(vault_atas), 100):
                chunk = vault_atas[i:i + 100]
                r = sol_rpc("getMultipleAccounts", [chunk, {"encoding": "base64",
                            "dataSlice": {"offset": 64, "length": 8}}])
                for j, acct in enumerate(r.get("value", []) if isinstance(r, dict) else (r or [])):
                    if not acct:
                        continue
                    try:
                        # dataSlice started at offset 64 => amount is first 8 bytes of the slice
                        amt = int.from_bytes(base64.b64decode(acct["data"][0])[0:8], "little")
                        mint = mints[chunk[j]]
                        tokens[f"solana:{mint}"] = tokens.get(f"solana:{mint}", 0) + amt
                    except Exception:
                        pass
        row["tokens"] = tokens
        raw_by_mint = {k.split(":", 1)[1]: v for k, v in tokens.items()}
        decs = sol_mint_decimals(list(raw_by_mint.keys()), raw_amounts=raw_by_mint)
        row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
        row["evidence"]["whirlpool_positions_note"] = "whirlpool position value not separately measured (vault ATAs measured)"
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "medium"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 7. Dojoswap AMM (Injective) ----------
def c_dojoswap():
    row = add("dojoswap-amm", "Dojoswap AMM", "Injective")
    factory = "inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk"
    row["custody"] = [f"factory {factory} + pair contracts"]
    lcds = ["https://injective-rest.publicnode.com", "https://lcd.injective.network"]
    try:
        pairs = []
        start = None
        for _ in range(60):
            q = {"pairs": {"limit": 30, **({"start_after": start} if start else {})}}
            data = None
            for lcd in lcds:
                try:
                    data = cosmos_lcd_smart(lcd, factory, q, timeout=25); break
                except Exception:
                    continue
            if not data:
                break
            batch = data.get("pairs", [])
            pairs += batch
            if len(batch) < 30:
                break
            # terraswap pagination: start_after = [AssetInfo; 2] of last pair
            start = batch[-1].get("asset_infos")
            time.sleep(0.15)
        row["evidence"]["pairs"] = len(pairs)
        tokens = {}
        errs = [0]

        def fetch_pool(p):
            err = None
            for attempt in range(2):
                for lcd in lcds:
                    try:
                        pool = cosmos_lcd_smart(lcd, p["contract_addr"], {"pool": {}}, timeout=10)
                        return p, pool, None
                    except Exception as e:
                        err = redact(e)
                time.sleep(0.5)
            return p, None, err
        import concurrent.futures as cf
        with cf.ThreadPoolExecutor(max_workers=6) as ex:
            for p, pool, err in ex.map(fetch_pool, pairs):
                if err:
                    errs[0] += 1
                    continue
                for a in pool.get("assets", []):
                    info = a["info"]
                    if "native_token" in info:
                        key = "injective:" + info["native_token"]["denom"]
                    else:
                        key = "injective:" + info["token"]["contract_addr"]
                    tokens[key] = tokens.get(key, 0) + int(a["amount"])
        if errs[0]:
            row["errors"].append(f"{errs[0]} pool queries failed")
        row["tokens"] = tokens
        decs = {"injective:inj": 18}
        for t in list(tokens.keys()):
            addr = t.split(":", 1)[1]
            if addr.startswith("inj1"):
                try:
                    ti = cosmos_lcd_smart(lcds[0], addr, {"token_info": {}})
                    if ti.get("decimals") is not None:
                        decs[t] = int(ti["decimals"])
                except Exception:
                    pass
            else:
                if len([k for k in decs if not k.split(":", 1)[1].startswith("inj1")]) >= 60:
                    decs.setdefault(t, 6)
                    continue
                try:
                    meta = http(f"{lcds[0]}/cosmos/bank/v1beta1/denoms_metadata/{addr}", timeout=15)
                    md = (meta or {}).get("metadata") or {}
                    if md.get("decimals") is not None:
                        decs[t] = int(md["decimals"])
                    else:
                        units = md.get("denom_units") or []
                        if units:
                            decs[t] = int(units[-1].get("exponent") or 6)
                except Exception:
                    decs[t] = 6  # conservative default for native/IBC denoms on Injective
        row["token_decimals"] = decs
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 8. ErgoDEX (Ergo) ----------
ERGO_OWNER = ("5vSUZRZbdVbnk4sJWjg2uhL94VZWRg4iatK9VgMChufzUgdihgvhR8yWSUEJKszzV7Vmi6K8hCyKTNhUaiP8p5ko6YEU9yfHpjVuXdQ4i5p4cRCzch6ZiqWrNukYjv7Vs5jvBwqg5hcEJ8u1eerr537YLWUoxxi1M4vQxuaCihzPKMt8NDXP4WcbN6mfNxxLZeGBvsHVvVmina5THaECosCWozKJFBnscjhpr3AJsdaL8evXAvPfEjGhVMoTKXAb2ZGGRmR8g1eZshaHmgTg2imSiaoXU5eiF3HvBnDuawaCtt674ikZ3oZdekqswcVPGMwqqUKVsGY4QuFeQoGwRkMqEYTdV2UDMMsfrjrBYQYKUBFMwsQGMNBL1VoY78aotXzdeqJCBVKbQdD3ZZWvukhSe4xrz8tcF3PoxpysDLt89boMqZJtGEHTV9UBTBEac6sDyQP693qT3nKaErN8TCXrJBUmHPqKozAg9bwxTqMYkpmb9iVKLSoJxG7MjAj72SRbcqQfNCVTztSwN3cRxSrVtz4p87jNFbVtFzhPg7UqDwNFTaasySCqM")

def c_ergodex():
    row = add("ergodex", "ErgoDEX", "Ergo")
    row["custody"] = [ERGO_OWNER]
    try:
        r = http("https://api.ergoplatform.com/api/v1/addresses/" + ERGO_OWNER + "/balance/total", timeout=45)
        conf = r.get("confirmed", {})
        erg = conf.get("nanoErgs", 0) / 1e9
        tokens = {"native:ergo": erg}
        for t in conf.get("tokens", []):
            if t.get("amount"):
                tokens[f"ergo:{t['tokenId']}"] = t["amount"] / (10 ** (t.get("decimals") or 0))
        row["tokens"] = tokens
        row["evidence"]["nanoErgs"] = conf.get("nanoErgs")
        row["evidence"]["token_count"] = len(conf.get("tokens", []))
        r2 = http("https://api.ergoplatform.com/api/v1/boxes/unspent/byAddress/" + ERGO_OWNER + "?limit=1", timeout=45)
        row["evidence"]["unspent_boxes"] = r2.get("total") if isinstance(r2, dict) else None
        row["status"] = "LIVE-FUNDED" if erg > 0 else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 9. HLiquity (Hedera) ----------
def c_hliquity():
    row = add("hliquity", "HLiquity", "Hedera")
    tm = "0x00000000000000000000000000000000005c9f66"
    staking = "0x00000000000000000000000000000000005c9f30"
    hlqt = "0x00000000000000000000000000000000005c9f70"
    row["custody"] = [f"troveManager {tm}", f"staking {staking}", f"HLQT {hlqt}"]
    url = "https://mainnet.hashio.io/api"
    try:
        hbar_total = 0
        for name, sel in [("activePool", EV["activePool()"]), ("defaultPool", EV["defaultPool()"])]:
            ap = evm_rpc(url, "eth_call", [{"to": tm, "data": sel}, "latest"])
            addr = "0x" + ap[-40:]
            bal = evm_rpc(url, "eth_getBalance", [addr, "latest"])
            v = int(bal, 16) / 1e18
            hbar_total += v
            row["evidence"][f"{name}_address"] = addr
            row["evidence"][f"{name}_hbar"] = v
        hlqt_bal = evm_rpc(url, "eth_call", [{"to": hlqt, "data": EV["balanceOf(address)"] + "0" * 24 + staking[2:]}, "latest"])
        row["evidence"]["hlqt_staked"] = int(hlqt_bal, 16) / 1e18 if hlqt_bal and hlqt_bal != "0x" else 0
        row["tokens"] = {"native:hbar": hbar_total}
        row["status"] = "LIVE-FUNDED" if hbar_total > 0 else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 10. ShadeLend (Secret) ----------
def c_shadelend():
    row = add("shadelend", "ShadeLend", "Secret")
    row["custody"] = ["Shade Lend contracts on Secret (addresses not in public adapter; source = securesecrets.org API)"]
    try:
        r = http("https://prodv1.securesecrets.org/graphql", {
            "operationName": "getLendHistory",
            "variables": {"intervalIso": "2026-10-01T00:00:00.000Z"},
            "query": "query getLendHistory($intervalIso: String!) { lendStatsHistories(query: {where: {time: {gte: $intervalIso}}, orderBy: {time: \"desc\"}}) { collateralUsd debtUsd time } }"},
            timeout=25, retries=1)
        row["evidence"]["api"] = r
        row["status"] = "LIVE-FUNDED"
        row["confidence"] = "medium"
    except Exception as e:
        row["errors"].append(f"securesecrets API dead: {redact(e)}")
    for base in ["https://lcd-secret.publicnode.com", "https://secret-lcd.publicnode.com",
                 "https://api.secretapi.io", "https://lcd.secret.network", "https://scrt-rest.polkachu.com"]:
        try:
            r = http_text(f"{base}/cosmos/base/tendermint/v1beta1/node_info", timeout=12)
            row["evidence"]["secret_lcd"] = {"url": base, "ok": True, "sample": str(r)[:80]}
            break
        except Exception as e:
            row["errors"].append(f"{base}: {redact(e)}")
    if row["status"] == "UNKNOWN":
        row["status"] = "UNREACHABLE"
        row["confidence"] = "medium"
        row["notes"].append("DefiLlama deadFrom=2026-08-08; securesecrets API + public Secret LCDs unreachable from scanner")

# ---------- 11. Jet V1 (Solana) ----------
def c_jet():
    row = add("jet-v1", "Jet V1", "Solana")
    owner = "7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8"
    row["custody"] = [owner]
    token_program = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    tokens = {}
    try:
        r = sol_rpc("getProgramAccounts", [token_program, {
            "encoding": "base64",
            "filters": [{"memcmp": {"offset": 32, "bytes": owner}}],
            "dataSlice": {"offset": 0, "length": 72}}], timeout=120)
        row["evidence"]["accounts"] = len(r or [])
        for a in r or []:
            b = base64.b64decode(a["account"]["data"][0])
            mint = b58encode(b[0:32]); amt = int.from_bytes(b[64:72], "little")
            if amt:
                tokens[f"solana:{mint}"] = tokens.get(f"solana:{mint}", 0) + amt
    except Exception as e:
        row["errors"].append("getProgramAccounts: " + redact(e))
        try:
            r = sol_rpc("getTokenAccountsByOwner", [owner, {"programId": token_program}, {"encoding": "jsonParsed"}], timeout=120)
            vals = r.get("value", []) if isinstance(r, dict) else []
            row["evidence"]["accounts"] = len(vals)
            for a in vals:
                info = a["account"]["data"]["parsed"]["info"]
                amt = int(info["tokenAmount"]["amount"])
                if amt:
                    tokens[f"solana:{info['mint']}"] = tokens.get(f"solana:{info['mint']}", 0) + amt
        except Exception as e2:
            row["errors"].append("getTokenAccountsByOwner: " + redact(e2))
    row["tokens"] = tokens
    raw_by_mint = {k.split(":", 1)[1]: v for k, v in tokens.items()}
    decs = sol_mint_decimals(list(raw_by_mint.keys()), raw_amounts=raw_by_mint)
    row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
    row["evidence"]["debt_tokens_note"] = "debt mints G17Yu6f4..,5v8QVt..,A9S9XV..,7SXpzV.. excluded (borrowed side)"
    debt = {"G17Yu6f4emBeRLWS1Y4cNJMTmT5LUGJH95zK6253KoAH", "5v8QVtwqZjSdJxhCF2xWrAopiyhDgJTdgeQZ5aWmStnE",
            "A9S9XVCuNXHnJGFhxBhsTmJNHa6aPccF5NCAGgE4BxGF", "7SXpzVgqMvDEWkv9jtDUZVjkBPUbn8EUitKwV22WCpxt"}
    for d in debt:
        row["tokens"].pop(f"solana:{d}", None)
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in row["tokens"].values()) else ("DRAINED" if row["tokens"] else "UNREACHABLE")
    row["confidence"] = "high" if row["tokens"] else "low"

# ---------- 12. Lenfi (Cardano) ----------
LENFI_SCRIPTS = [
    "addr1zy9940grv28qxz9k82l9gmqd80vfd8a2734e35yzsz9cqktfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9smq5w00",
    "addr1zykhtew0z93z6hmgu2ew7kl9puqz0wmafp0f3jypuejkwmrfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9skq4p22",
    "addr1zxfgvtfgp9476dhmq8fkm3x8wg20v33s6c9unyxmnpm0y5rfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9st8q78h",
    "addr1zxcjtxuc7mj8w6v9l3dfxvm30kxf78nzw387mqjqvszxr4mfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sp92046",
    "addr1zytwe3qhc0kf5k8yaur60cnhcxjg9zvfdnftp0rfu2czprtfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sgzwepc",
    "addr1zyc7w5n699ews00yujnhw59g4nuzykuzgl5x6nzqp49zv5tfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sdyxnxc",
    "addr1zy6v8c7xdhftln7zk5uvt9h6jaknaxlx6hz5nkw63mpgwamfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sw9snf6",
    "script1xt5vpt33fm6tu3fvz65enpnlvmg6z7gle9evktmuwn3c6gjfc7p",
    "script1nwvlaa0wnf43wzjp3xv738k6myam74dlrlh027mq20trg3ng772",
    "script1sqscxzh7mkzlmgf98k3tuadkds8xt3yzzj8t3jnfpypukld9xck",
]

def c_lenfi():
    row = add("lenfi", "Lenfi", "Cardano")
    row["custody"] = LENFI_SCRIPTS + ["staking addr1wyvej5rmcrhfpcwrwmnqsjtwvf8gv3dn64vwy3xzekp95wqqhdkwa (LENFI)"]
    try:
        info = http("https://api.koios.rest/api/v1/address_info", {"_addresses": LENFI_SCRIPTS}, timeout=60)
        total_lovelace = 0
        by_addr = {}
        if isinstance(info, list):
            for a in info:
                bal = int(a.get("balance") or 0)
                total_lovelace += bal
                by_addr[a["address"][:20]] = bal
        row["evidence"]["lovelace_by_addr"] = by_addr
        row["evidence"]["total_lovelace"] = total_lovelace
        tokens = {"native:ada": total_lovelace / 1e6}
        try:
            assets = http("https://api.koios.rest/api/v1/address_assets", {"_addresses": LENFI_SCRIPTS}, timeout=60)
            if isinstance(assets, list):
                row["evidence"]["address_assets_rows"] = len(assets)
                decs = {}
                for a in assets:
                    unit = (a.get("policy_id") or "") + (a.get("asset_name") or "")
                    qty = int(a.get("quantity") or 0)
                    if qty:
                        tokens[f"cardano:{unit}"] = tokens.get(f"cardano:{unit}", 0) + qty
                        decs[f"cardano:{unit}"] = int(a.get("decimals") or 0)
                row["token_decimals"] = decs
        except Exception as e:
            row["errors"].append("address_assets: " + redact(e))
        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if total_lovelace > 0 else "DRAINED"
        row["confidence"] = "medium"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

def _collect_lsu(rd, redemption, validators):
    for it in rd.get("items", []):
        meta = {m["key"]: m for m in (it.get("metadata", {}) or {}).get("items", [])}
        val = meta.get("validator", {}).get("value", {}).get("typed", {}).get("value")
        if val and val.startswith("validator_"):
            redemption[it["address"]] = {"validator": val,
                                         "total_supply": it.get("details", {}).get("total_supply")}
            validators.append(val)

# ---------- 13. CaviarNine LSU Pool (Radix) ----------
def c_caviarnine():
    row = add("caviarnine-lsu-pool", "CaviarNine LSU Pool", "Radix")
    comp = "component_rdx1cppy08xgra5tv5melsjtj79c0ngvrlmzl8hhs7vwtzknp9xxs63mfp"
    row["custody"] = [comp]
    try:
        r = http("https://mainnet.radixdlt.com/state/entity/details",
                 {"addresses": [comp], "opt_ins": {"explicit_metadata": ["name"]}}, timeout=40)
        item = (r.get("items") or [{}])[0]
        fung = (item.get("fungible_resources") or {}).get("items") or []
        row["evidence"]["ledger_state"] = r.get("ledger_state", {}).get("state_version")
        resources = []
        for f in fung:
            resources.append({"resource": f["resource_address"], "amount": f["amount"]})
        row["evidence"]["fungibles"] = resources
        lsu_res = [x["resource"] for x in resources if x["resource"].startswith("resource_")]
        redemption = {}
        try:
            if lsu_res:
                validators = []
                for i in range(0, len(lsu_res), 20):
                    rd = http("https://mainnet.radixdlt.com/state/entity/details",
                              {"addresses": lsu_res[i:i + 20], "aggregation_level": "Vault",
                               "explicit_metadata": ["validator"]}, timeout=40)
                    _collect_lsu(rd, redemption, validators)
                for i in range(0, len(validators), 20):
                    vd = http("https://mainnet.radixdlt.com/state/entity/details",
                              {"addresses": validators[i:i + 20], "aggregation_level": "Vault"}, timeout=40)
                    for v in vd.get("items", []):
                        st = (v.get("details", {}).get("state", {}) or {})
                        su = st.get("stake_unit_resource_address")
                        stake_xrd_vault = (st.get("stake_xrd_vault", {}) or {}).get("entity_address")
                        xrd_res = [x for x in (v.get("fungible_resources", {}) or {}).get("items", [])
                                   if x["resource_address"].endswith("radxrdxxxxxxxxx009923554798xxxxxxxxxradxrd")]
                        xrd_bal = None
                        for x in xrd_res:
                            for vault in (x.get("vaults", {}) or {}).get("items", []):
                                if vault.get("vault_address") == stake_xrd_vault:
                                    xrd_bal = float(vault.get("amount"))
                        if su in redemption and xrd_bal and redemption[su].get("total_supply"):
                            try:
                                redemption[su]["xrd_redemption"] = xrd_bal / float(redemption[su]["total_supply"])
                            except Exception:
                                pass
        except Exception as e:
            row["errors"].append("lsu redemption: " + redact(e))
        row["evidence"]["lsu_redemption"] = redemption
        tokens = {}
        for x in resources:
            r_ = x["resource"]; amt = float(x["amount"])
            if r_ in redemption and redemption[r_].get("xrd_redemption"):
                tokens["native:xrd"] = tokens.get("native:xrd", 0) + amt * redemption[r_]["xrd_redemption"]
            elif r_.endswith("radxrdxxxxxxxxx009923554798xxxxxxxxxradxrd"):
                tokens["native:xrd"] = tokens.get("native:xrd", 0) + amt
            else:
                tokens[f"radix:{r_}"] = amt
        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 14. Omm (ICON) ----------
def c_omm():
    row = add("omm", "Omm", "Icon")
    dp = "cx5f9a6ca11b2b761a469965cedab40ada9e503cb5"
    row["custody"] = [dp]
    try:
        r = http("https://ctz.solidwallet.io/api/v3", {"jsonrpc": "2.0", "id": 1, "method": "icx_call",
                 "params": {"to": dp, "dataType": "call", "data": {"method": "getAllReserveData", "params": {}}}}, timeout=45)
        d = r.get("result") or {}
        reserves, cash_usd, total_usd, borrowed_usd = {}, 0.0, 0.0, 0.0
        tokens = {}
        for sym, v in d.items():
            liq = int(v.get("totalLiquidityUSD", "0x0"), 16) / 1e18
            bor = int(v.get("totalBorrowsUSD", "0x0"), 16) / 1e18
            avail = int(v.get("availableLiquidityUSD", "0x0"), 16) / 1e18
            dec = int(v.get("decimals", "0x12"), 16)
            raw = int(v.get("availableLiquidity", "0x0"), 16)
            reserves[sym] = {"availableLiquidity": raw / (10 ** dec), "decimals": dec,
                             "availableLiquidityUSD": avail,
                             "totalLiquidityUSD": liq, "totalBorrowsUSD": bor}
            cash_usd += avail
            total_usd += liq
            borrowed_usd += bor
            if raw > 0:
                tokens[f"icon:{sym}"] = raw
                row["token_decimals"][f"icon:{sym}"] = dec
        row["evidence"]["reserves"] = reserves
        row["evidence"]["cash_usd_contract_oracle"] = round(cash_usd, 2)
        row["evidence"]["total_liquidity_usd"] = round(total_usd, 2)
        row["evidence"]["total_borrows_usd"] = round(borrowed_usd, 2)
        row["tokens"] = tokens
        row["live_usd"] = round(cash_usd, 2)
        row["notes"].append("live_usd = cash only (availableLiquidityUSD, contract oracle); borrows recorded separately")
        row["status"] = "LIVE-FUNDED" if cash_usd > 100 else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 15. Taiga Acala (Acala / Tapio) ----------
def substrate_tokens_of(url, ss58_addr, currency_ids, decimals=10):
    pub = ss58_decode(ss58_addr)
    prefix = twox128(b"Tokens") + twox128(b"Accounts") + blake2_128_concat(pub)
    keys = substrate_rpc(url, "state_getKeysPaged", ["0x" + prefix.hex(), 50, None]) or []
    out = {}
    for k in keys:
        tail = bytes.fromhex(k[2:])[len(prefix):]
        cid = tail[8:]
        v = substrate_rpc(url, "state_getStorage", [k])
        if v and v != "0x":
            free = int.from_bytes(bytes.fromhex(v[2:])[0:16], "little")
            out[cid.hex()] = free / (10 ** decimals)
    return out

def c_taiga():
    row = add("taiga-acala", "Taiga Acala", "Acala")
    acct = "23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9"
    row["custody"] = [f"Acala module account {acct} (tapio LSD)"]
    try:
        url = "https://acala-rpc-0.aca-api.network"
        toks_raw = substrate_tokens_of(url, acct, None, decimals=0)
        CID_DEC = {"0000": 12, "0001": 12, "0002": 10, "0003": 10, "0004": 12}
        toks = {k: v / (10 ** CID_DEC.get(k, 12)) for k, v in toks_raw.items()}
        row["evidence"]["orml_tokens_by_currency_hex"] = toks_raw
        row["evidence"]["orml_tokens_scaled"] = toks
        tokens = {}
        if "0002" in toks: tokens["native:dot"] = toks["0002"]
        if "0003" in toks: tokens["native:ldot"] = toks["0003"]
        for k, v in toks.items():
            if k not in ("0002", "0003"):
                tokens[f"acala:{k}"] = v
        # native ACA
        pub = ss58_decode(acct)
        k2 = twox128(b"System") + twox128(b"Account") + blake2_128_concat(pub)
        v = substrate_rpc(url, "state_getStorage", ["0x" + k2.hex()])
        if v and v != "0x":
            row["evidence"]["aca_free"] = int.from_bytes(bytes.fromhex(v[2:])[16:32], "little") / 1e12
        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 16. 01 (Solana) ----------
def c_01():
    row = add("01", "01", "Solana")
    owner = "HjHSNe8hhvZ8hKCRrhKg1DGiGPd9NYQbUjT1SQRDo4kZ"
    row["custody"] = [owner]
    token_program = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    tokens = {}
    try:
        r = sol_rpc("getTokenAccountsByOwner", [owner, {"programId": token_program}, {"encoding": "jsonParsed"}], timeout=90)
        vals = r.get("value", []) if isinstance(r, dict) else []
        row["evidence"]["accounts"] = len(vals)
        for a in vals:
            info = a["account"]["data"]["parsed"]["info"]
            amt = int(info["tokenAmount"]["amount"])
            if amt:
                tokens[f"solana:{info['mint']}"] = tokens.get(f"solana:{info['mint']}", 0) + amt
    except Exception as e:
        row["errors"].append(redact(e))
    row["tokens"] = tokens
    raw_by_mint = {k.split(":", 1)[1]: v for k, v in tokens.items()}
    decs = sol_mint_decimals(list(raw_by_mint.keys()), raw_amounts=raw_by_mint)
    row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else ("DRAINED" if row.get("evidence", {}).get("accounts") is not None else "UNREACHABLE")
    row["confidence"] = "medium"

# ---------- 17. Ocean One (Mixin) ----------
def c_oceanone():
    row = add("ocean-one", "Ocean One", "Mixin")
    row["custody"] = ["Ocean One Mixin app custody (address not in public adapter)"]
    for u in ["https://events.ocean.one/assets", "http://events.ocean.one/assets"]:
        try:
            r = http_text(u, timeout=15)
            row["evidence"]["events_api"] = {"url": u, "sample": str(r)[:200]}
            break
        except Exception as e:
            row["errors"].append(f"{u}: {redact(e)}")
    try:
        r = http_text("https://api.mixin.one/network/chains", timeout=20)
        row["evidence"]["mixin_api"] = "alive"
    except Exception as e:
        row["errors"].append("api.mixin.one: " + redact(e))
    row["status"] = "UNREACHABLE"
    row["confidence"] = "medium"
    row["notes"].append("deadFrom=2024-01-21; adapter TVL source events.ocean.one dead; custody address not discoverable from public sources")

# ---------- 18. Moria Protocol (BCH) ----------
MORIA_ADDR = "rvtgwvmtp4hy5k9alcwc5yt69k4jnshevdwapq43w7hp8m7hwj60szuun6naf"
MUSD = "b38a33f750f84c5c169a6f23cb873e6e79605021585d4f3408789689ed87f366"

def fulcrum_call(host, port, method, params, proto="1.4.3"):
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    with socket.create_connection((host, port), timeout=25) as raw:
        with ctx.wrap_socket(raw, server_hostname=host) as s:
            def send(obj):
                s.sendall((json.dumps(obj) + "\n").encode())
                buf = b""
                while b"\n" not in buf:
                    chunk = s.recv(65536)
                    if not chunk:
                        break
                    buf += chunk
                return json.loads(buf.split(b"\n")[0].decode())
            try:
                send({"id": 0, "method": "server.version", "params": ["l2-triage", proto]})
            except Exception:
                pass
            return send({"id": 1, "method": method, "params": params})

def moria_ws_call(method, params):
    """Minimal WebSocket client for wss://rostrum.moria.money:443."""
    host = "rostrum.moria.money"
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    raw = socket.create_connection((host, 443), timeout=25)
    s = ctx.wrap_socket(raw, server_hostname=host)
    key = base64.b64encode(os.urandom(16)).decode()
    req = (f"GET / HTTP/1.1\r\nHost: {host}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
           f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
    s.sendall(req.encode())
    hdr = b""
    while b"\r\n\r\n" not in hdr:
        hdr += s.recv(4096)
    def ws_send(payload: bytes):
        import struct
        mask = os.urandom(4)
        n = len(payload)
        if n < 126:
            frame = bytes([0x81, 0x80 | n]) + mask
        elif n < 65536:
            frame = bytes([0x81, 0x80 | 126]) + struct.pack(">H", n) + mask
        else:
            frame = bytes([0x81, 0x80 | 127]) + struct.pack(">Q", n) + mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        s.sendall(frame + masked)
    def ws_recv():
        import struct
        b = s.recv(2)
        if not b:
            return None
        fin_op, ln = b[0], b[1] & 0x7F
        if ln == 126:
            ln = struct.unpack(">H", s.recv(2))[0]
        elif ln == 127:
            ln = struct.unpack(">Q", s.recv(8))[0]
        data = b""
        while len(data) < ln:
            data += s.recv(ln - len(data))
        return data.decode("utf-8", "replace")
    ws_send(json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode())
    deadline = time.time() + 25
    while time.time() < deadline:
        msg = ws_recv()
        if msg and '"id":1' in msg.replace(" ", ""):
            s.close()
            return json.loads(msg)
    s.close()
    raise RuntimeError("rostrum ws timeout")

def c_moria():
    row = add("moria-protocol", "Moria Protocol", "BitcoinCash")
    row["custody"] = [f"loan contract {MORIA_ADDR} (CashTokens UTXOs)", f"MUSD token {MUSD}"]
    hosts = [("bch.imaginary.cash", 50002), ("fulcrum.greyh.at", 50002),
             ("bch.cyberbits.eu", 50002), ("electrum.imaginary.cash", 50002),
             ("electroncash.dk", 50002), ("bch.loping.net", 50002)]
    got_any = False
    for host, port in hosts:
        try:
            r = fulcrum_call(host, port, "blockchain.address.get_balance", [MORIA_ADDR])
            bal = r.get("result")
            if isinstance(bal, dict):
                conf = int(bal.get("confirmed", 0) or 0)
                row["evidence"]["balance_source"] = f"{host}:{port}"
                row["evidence"]["confirmed_sats"] = conf
                got_any = True
                r2 = fulcrum_call(host, port, "blockchain.address.get_history", [MORIA_ADDR])
                h = r2.get("result")
                row["evidence"]["history_entries"] = len(h) if isinstance(h, list) else None
                try:
                    r3 = fulcrum_call(host, port, "token.address.listunspent", [MORIA_ADDR, None, MUSD], "1.6")
                    if isinstance(r3, dict) and "result" in r3:
                        unspent = r3["result"]
                        unspent = unspent.get("unspent", unspent) if isinstance(unspent, dict) else unspent
                        loan = [u for u in (unspent or []) if u.get("commitment")]
                        sats = sum(int(u.get("value", 0)) for u in loan)
                        row["evidence"]["token_utxos"] = len(unspent or [])
                        row["evidence"]["token_utxos_with_commitment"] = len(loan)
                        row["evidence"]["collateral_sats"] = sats
                        row["tokens"] = {"native:bitcoincash": sats / 1e8}
                        row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
                        row["confidence"] = "high"
                        break
                    elif isinstance(r3, dict) and "error" in r3:
                        row["errors"].append(f"token RPC {host}: {str(r3['error'])[:80]}")
                except Exception as e:
                    row["errors"].append(f"token RPC {host}: {redact(e)}")
                sats = conf
                row["tokens"] = {"native:bitcoincash": sats / 1e8}
                row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
                row["confidence"] = "medium"
                row["notes"].append("plain blockchain.address.* used (Fulcrum 2.x token.address.* unsupported on public servers)")
                break
        except Exception as e:
            row["errors"].append(f"{host}: {redact(e)}")
    if not got_any:
        try:
            r = moria_ws_call("token.address.listunspent", [MORIA_ADDR, None, MUSD])
            unspent = r.get("result")
            unspent = unspent.get("unspent", unspent) if isinstance(unspent, dict) else unspent
            loan = [u for u in (unspent or []) if u.get("commitment")]
            sats = sum(int(u.get("value", 0)) for u in loan)
            row["evidence"]["source"] = "wss://rostrum.moria.money:443"
            row["evidence"]["collateral_sats"] = sats
            row["tokens"] = {"native:bitcoincash": sats / 1e8}
            row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
            row["confidence"] = "high"
        except Exception as e:
            row["errors"].append("rostrum ws: " + redact(e))
            row["status"] = "UNREACHABLE"; row["confidence"] = "low"

# ---------- 19. Margined Protocol (Neutron/Osmosis) ----------
MARGINED_OSMO = {
    "stOSMO": "osmo16s3sxs5886p42kteunp6370pken2n5ukzszz0trkr39epqtawn2qk4r9l5",
    "stTIA": "osmo1q3w9kedgtc8sdh7xlcr77ydv3qu7fs2e3q6xznysp2lrdfyz9xyqv26yqv",
    "ampOSMO": "osmo1cztgw4e467vjljd0s2flz8asu3x3wg9q0ttga9t6kzmpyaauxxrs2gjshq",
    "bOSMO": "osmo159f7axyc32cyfgzx0gs9r98jwpgutj5qz4ns97xvu7nw3xzpavzsg2uxr3",
    "qOSMO": "osmo18vk0rsu4qwzx74g9alu2f7x5zs99sluwkuh5wp70yed2ne4pmutqf9lvdu",
    "usdcaxlGrid": "osmo1qngwlgzt0r3fdg6zgln5wa6mr5c7t6fek3qqgxesujjak5ds747sy6qu2f",
    "OSMORedemption": "osmo15fqmdl8lfl9h0qflljd63ufw9j2m7xmsk3hu5vsn8xpta4hk5chqt7mddc",
    "TIARedemption": "osmo1reyz7pwu7y9e7lmzqg6j4h7jcv32du7n7jhnk2lz93a9lxr56ess2qtgzl",
    "ATOMRedemption": "osmo1hvl5kj4xzdj4udxjv2dzk2zfqhzkd9afqygwq3t84tn53e0250zqrltj48",
    "DYDXRedemption": "osmo1grs74ux62lukjdlfs9ll4myyulcyjcd4uzwpw3cgnzdygtsspp2se2ense",
}
MARGINED_NEUTRON = {
    "ATOMFund": "neutron1puedrclm6rn33x3zv66xg6m23qcdagayqua6jj2wqzvfznlqef8qe53wr2",
    "NTRNStructured": "neutron13h4jzme5880knnc23xvwu9gytynnxu5cc0fek6fndmjyctzznj9sd5yhhy",
    "ATOMdATOM": "neutron1f99ujxefjr4jqmskc7hvg09am6pdq2j2c5049xwl0de4cavc4rfsl866y0",
    "wBTCUSDC": "neutron17fyzkafg4scrd6xu0sp9llrl6hazegza7yer4erlea0kvk30yxsqk2xqfd",
    "NTRNUSDC": "neutron1t0fl9k43g86sv60ghx9vtwed9rpgtf49rxzm05ff477j23h52c6s0urdc7",
    "TIAUSDC": "neutron1wv8pl7tsatzx6n9yaqfksvu5y0x7j50g6mhy636udwfn3vyqp0hsu7g8yk",
    "ATOMUSDC": "neutron1krqwpk0kmphl93kykavp2fnr88g5rnrpk40c34a55yrl00tmfz0s99ewc6",
    "TIAFund": "neutron14q3umuuvyv6mndd5acuc3n8u5mlvrrq3kkzrputu3rkhz8nd2uzqmfl4v6",
}

def c_margined():
    row = add("margined-protocol", "Margined Protocol", "Neutron,Osmosis")
    row["custody"] = list(MARGINED_OSMO.values()) + list(MARGINED_NEUTRON.values())
    tokens = {}
    osmo_lcds = ["https://osmosis-rest.publicnode.com", "https://lcd.osmosis.zone"]
    neutron_lcds = ["https://neutron-api.polkachu.com", "https://lcd-neutron.keplr.app",
                    "https://neutron-rest.publicnode.com", "https://rest-kralum.neutron-1.neutron.org"]
    def vault_query(vaults, lcds, prefix, label):
        for name, c in vaults.items():
            ok = False
            for attempt in range(3):
                for lcd in lcds:
                    try:
                        info = cosmos_lcd_smart(lcd, c, {"info": {}}, timeout=25)
                        ta = cosmos_lcd_smart(lcd, c, {"total_assets": {}}, timeout=25)
                        base = info.get("base_token")
                        amt = int(ta.get("amount", ta) if isinstance(ta, dict) else ta)
                        tokens[f"{prefix}:{base}"] = tokens.get(f"{prefix}:{base}", 0) + amt
                        ok = True
                        break
                    except Exception as e:
                        row["errors"].append(f"{label} {name} @{lcd}: {redact(e)}")
                if ok:
                    break
                time.sleep(1.5)
    vault_query(MARGINED_OSMO, osmo_lcds, "osmosis", "osmo")
    vault_query(MARGINED_NEUTRON, neutron_lcds, "neutron", "neutron")
    row["tokens"] = tokens
    decs = {}
    for t in tokens:
        d = t.split(":", 1)[1]
        if d in ("uosmo", "untrn"):
            decs[t] = 6
        elif d.startswith(("ibc/", "factory/", "gamm/")):
            decs[t] = 6
        elif d.startswith("u") and len(d) <= 6:
            decs[t] = 6
    row["token_decimals"] = decs
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else ("DRAINED" if tokens else "UNREACHABLE")
    row["confidence"] = "medium"

# ---------- 20. SuiDollar Basis (Sui) ----------
def c_suidollar():
    row = add("suidollar-basis", "SuiDollar Basis", "Sui")
    row["custody"] = ["not published in adapter (deadFrom 2025-10-21); source adapter deleted"]
    row["notes"].append("adapter tvl() is empty by design (deadFrom 2025-10-21); no custody addresses recoverable from DefiLlama")
    row["status"] = "UNREACHABLE"
    row["confidence"] = "low"

# ---------- 21. HashMix FIL (Filecoin) ----------
def c_hashmix():
    row = add("hashmix-fil", "HashMix FIL", "Filecoin")
    pool = "0x587A7eaE9b461ad724391Aa7195210e0547eD11d"
    row["custody"] = [pool]
    try:
        bal = evm_rpc("https://api.node.glif.io/rpc/v1", "eth_getBalance", [pool, "latest"])
        fil = int(bal, 16) / 1e18
        row["tokens"] = {"native:fil": fil}
        row["evidence"]["pool_fil"] = fil
        row["status"] = "LIVE-FUNDED" if fil > 0 else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"
    try:
        r = http_text("https://fvm.hashmix.org/fevmapi/tvl", timeout=15)
        row["evidence"]["hashmix_api"] = str(r)[:120]
    except Exception as e:
        row["errors"].append("fvm.hashmix.org: " + redact(e))

# ---------- 22. Fountain Protocol (Oasis) ----------
FOUNTAIN = [
    ("0xA7684aE7e07Dac91113900342b3ef25B9Fd1D841", "0xd7d588babfb99e82cd6dd0ca7677a5599aa678b5"),
    ("0x1C0C30795802Bf2B3232a824f41629BbBCF63127", None),
    ("0x7c4d0c834701C6E7F57b8c1424d30aDC46eA0840", "0x63f1fe2e1da490611fc16e4a5d92b7ec7d0911a9"),
]

def c_fountain():
    row = add("fountain-protocol", "Fountain Protocol", "Oasis")
    row["custody"] = [c for c, _ in FOUNTAIN]
    urls = ["https://emerald.oasis.dev", "https://emerald.oasis.io"]
    url = None
    for u in urls:
        try:
            evm_rpc(u, "eth_blockNumber", []); url = u; break
        except Exception as e:
            row["errors"].append(f"{u}: {redact(e)}")
    if not url:
        row["status"] = "UNREACHABLE"; return
    row["evidence"]["rpc"] = url
    try:
        row["evidence"]["block"] = int(evm_rpc(url, "eth_blockNumber", []), 16)
        tokens, markets_out = {}, {}
        for comp, _cether in FOUNTAIN:
            try:
                raw = evm_rpc(url, "eth_call", [{"to": comp, "data": EV["getAllMarkets()"]}, "latest"])
                b = bytes.fromhex(raw[2:])
                n = int.from_bytes(b[32:64], "big")
                mks = []
                for i in range(n):
                    mks.append("0x" + b[64 + i * 32 + 12: 96 + i * 32].hex())
                markets_out[comp] = {"n_markets": n, "markets": mks}
                for m in mks:
                    try:
                        cash = evm_rpc(url, "eth_call", [{"to": m, "data": EV["getCash()"]}, "latest"])
                        bor = evm_rpc(url, "eth_call", [{"to": m, "data": EV["totalBorrows()"]}, "latest"])
                        und_a = None
                        try:
                            und = evm_rpc(url, "eth_call", [{"to": m, "data": EV["underlying()"]}, "latest"])
                            und_a = "0x" + und[-40:] if und and len(und) >= 42 else None
                        except Exception:
                            pass
                        cash_v = int(cash, 16) if cash and cash != "0x" else 0
                        bor_v = int(bor, 16) if bor and bor != "0x" else 0
                        if und_a:
                            key = f"oasis:{und_a}"
                            try:
                                dec = evm_rpc(url, "eth_call", [{"to": und_a, "data": EV["decimals()"]}, "latest"])
                                if dec and dec != "0x":
                                    row["token_decimals"][key] = int(dec, 16)
                            except Exception:
                                pass
                        else:
                            key = "native:rose"
                            row["token_decimals"][key] = 18
                        tokens[key] = tokens.get(key, 0) + cash_v  # custody = cash only
                        row["evidence"].setdefault("market_detail", {})[m] = {
                            "underlying": und_a, "cash": cash_v, "borrows": bor_v}
                        row["evidence"]["cash_plus_borrows_by_market"] = \
                            row["evidence"].get("cash_plus_borrows_by_market", {})
                        row["evidence"]["cash_plus_borrows_by_market"][m] = cash_v + bor_v
                    except Exception as e:
                        row["errors"].append(f"market {m}: {redact(e)}")
            except Exception as e:
                row["errors"].append(f"comptroller {comp}: {redact(e)}")
        row["evidence"]["comptrollers"] = markets_out
        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "medium"
        row["notes"].append("live_usd = cash (underlying held by markets); borrows recorded separately in evidence (cash+borrows = TVL convention)")
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ================================================================ pricing
NATIVE_ALIAS = {
    "native:bitcoin": "coingecko:bitcoin", "native:bitcoincash": "coingecko:bitcoin-cash",
    "native:ergo": "coingecko:ergo", "native:hbar": "coingecko:hedera-hashgraph",
    "native:fil": "coingecko:filecoin", "native:ada": "coingecko:cardano",
    "native:dot": "coingecko:polkadot", "native:ldot": "coingecko:liquid-staking-dot",
    "native:xrd": "coingecko:radix", "native:sol": "coingecko:solana",
    "native:inj": "injective:inj", "native:osmo": "osmosis:uosmo",
    "native:icx": "coingecko:icon", "native:aca": "coingecko:acala",
    "native:rose": "coingecko:oasis-network",
    "icon:USDC": "coingecko:usd-coin", "icon:USDS": "coingecko:usds",
    "icon:bnUSD": "coingecko:balanced-dollar", "icon:ICX": "coingecko:icon",
}
# tokens with no direct DefiLlama price key -> (proxy key, multiplier); proxy keys are force-fetched
PRICE_FALLBACK = {
    "native:ldot": ("coingecko:polkadot", 1.0),  # LDOT ~ DOT parity
    "osmosis:ibc/D176154B0C63D1F9C6DCFB4F70349EBF2E2B5A87A05902F57A6AE92B863E9AEC": ("coingecko:stride-staked-osmo", 1.0),  # stOSMO
    "osmosis:ibc/D79E7D83AB399BFFF93433E54FAA480C191248FC556924A2A8351AE2638B3877": ("coingecko:celestia", 1.0),  # TIA
    "osmosis:ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2": ("coingecko:cosmos", 1.0),  # ATOM
    "osmosis:ibc/42D24879D4569CE6477B7E88206ADBFE47C222C6CAD51A54083E4A72594269FC": ("osmosis:uosmo", 1.0),  # qOSMO
    "osmosis:factory/osmo1dv8wz09tckslr2wy5z86r46dxvegylhpt97r9yd6qc3kyc6tv42qa89dr9/ampOSMO": ("osmosis:uosmo", 1.0),
    "osmosis:factory/osmo1s3l0lcqc7tu0vpj6wdjz9wqpxv8nk6eraevje4fuwkyjnwuy82qsx3lduv/boneOsmo": ("osmosis:uosmo", 1.0),
    "neutron:ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9": ("coingecko:cosmos", 1.0),  # ATOM
}

DECIMALS_HINT = {
    # sui type -> decimals (native SUI 9)
    "0x2::sui::SUI": 9,
}
# known token decimals for large-circulating tokens (fallback when price feed missing)
KNOWN_DECIMALS = {
    "native:bitcoin": 8, "native:bitcoincash": 8, "native:ergo": 9, "native:hbar": 18,
    "native:fil": 18, "native:ada": 6, "native:dot": 10, "native:ldot": 10,
    "native:xrd": 18, "native:sol": 9, "native:inj": 18, "native:osmo": 6,
    "native:scrt": 6, "native:icx": 18, "native:aca": 12, "native:eth": 18,
    "native:usdc": 6, "native:usdt": 6,
}

def price_key_for(tok):
    if tok in NATIVE_ALIAS:
        return NATIVE_ALIAS[tok]
    return tok  # e.g. sui:0x..., solana:<mint>, osmosis:<denom>, starknet:0x...

def valuate():
    all_keys = set()
    for r in RESULTS:
        for t in r.get("tokens", {}):
            all_keys.add(price_key_for(t))
    all_keys.add("coingecko:polkadot")
    for fbkey, _m in PRICE_FALLBACK.values():
        all_keys.add(fbkey)
    prices = price_of(None, all_keys)
    for r in RESULTS:
        usd = 0.0
        unknown = []
        breakdown = {}
        decs = r.get("token_decimals") or {}
        for t, amt in (r.get("tokens") or {}).items():
            pk = price_key_for(t)
            p = prices.get(pk)
            if p is None and t in PRICE_FALLBACK:
                fbkey, mult = PRICE_FALLBACK[t]
                fb = prices.get(fbkey)
                if fb:
                    p = fb * mult
                    r["notes"].append(f"{t} valued via proxy {fbkey} (x{mult})")
            dec = decs.get(t, 0)
            if p is None:
                unknown.append(t)
                continue
            NEEDS_DEC = ("sui:", "solana:", "starknet:", "injective:", "cardano:", "osmosis:",
                         "neutron:", "oasis:", "icon:")
            if t.startswith(NEEDS_DEC) and t not in decs:
                unknown.append(t + " (no decimals)")
                continue
            val = amt / (10 ** dec) if dec else amt
            usd += val * p
            breakdown[t] = {"amount": amt, "decimals": dec, "price": p, "usd": round(val * p, 2)}
        r["price_breakdown"] = breakdown
        r["unpriced_tokens"] = unknown[:40]
        if r.get("live_usd") is None:
            r["live_usd"] = round(usd, 2)
        else:
            r["live_usd"] = round(max(r["live_usd"], usd), 2)

def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    collectors = [c_fiamma, c_bluemove, c_jediswap, c_10kswap, c_sft, c_armada, c_dojoswap,
                  c_ergodex, c_hliquity, c_shadelend, c_jet, c_lenfi, c_caviarnine, c_omm,
                  c_taiga, c_01, c_oceanone, c_moria, c_margined, c_suidollar, c_hashmix, c_fountain]
    for c in collectors:
        slug = c.__name__.replace("c_", "").replace("_", "-")
        if only and only not in c.__name__:
            continue
        t0 = time.time()
        try:
            c()
            log(f"OK   {c.__name__} ({time.time()-t0:.1f}s)")
        except Exception as e:
            log(f"FAIL {c.__name__}: {redact(e)}")
            add(slug, slug, "?").update({"status": "UNREACHABLE", "errors": [redact(e)]})
    # llama cross-check
    for r in RESULTS:
        r["llama"] = llama_now(r["slug"])
    valuate()
    out = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "rows": RESULTS, "log": LOG[-400:]}
    with open(os.path.join(OUTDIR, "results.json"), "w") as f:
        json.dump(out, f, indent=2)
    with open(os.path.join(OUTDIR, "results.csv"), "w") as f:
        f.write("slug,protocol,chain,status,live_usd,confidence,n_tokens,errors\n")
        for r in RESULTS:
            f.write(f"{r['slug']},{r['protocol']},{r['chain']},{r['status']},{r.get('live_usd')},"
                    f"{r['confidence']},{len(r.get('tokens') or {})},{'; '.join(r['errors'][:2])[:200]!r}\n")
    print("=== SUMMARY ===")
    for r in sorted(RESULTS, key=lambda x: -(x.get("live_usd") or 0)):
        print(f"{r['slug']:24s} {r['chain']:16s} {r['status']:14s} ${r.get('live_usd') or 0:>14,.2f}  {r['confidence']}")

if __name__ == "__main__":
    main()
