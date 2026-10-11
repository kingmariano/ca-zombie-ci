#!/usr/bin/env python3
"""
L2-Triage-A custody enumeration (CI job) — v2 final.
Reads analysis/targets.json, probes contracts across chains, reads live balances
(GoldRush balances_v2 where supported; raw RPC token scans otherwise), enumerates
uni-v2 factory pairs, comptroller markets, Aave-fork lending pools (provider follow),
and protocol-specific handlers. Writes results to ci-out/. Stdlib only.
NEVER logs secrets/RPC URLs.
"""
import json, os, re, sys, time, base64, hashlib
import urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # folder root
OUT = os.path.join(BASE, "ci-out")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-ci"}
URL_RE = re.compile(r"https?://\S+")

def redact(s):
    return URL_RE.sub("<url-redacted>", str(s))[:300]

def env(*names):
    for n in names:
        v = os.environ.get(n)
        if v: return v
    return None

CHAINS = {
    "ethereum":   {"rpc": [env("NODE_REAL_ETH_RPC_URL"), env("BLOCKPI_RPC_URL"), env("RPC_URL"),
                           "https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth"],
                   "gr": "eth-mainnet", "llama": "ethereum", "cid": 1},
    "bsc":        {"rpc": [env("BSC_RPC_URL"), "https://bsc-rpc.publicnode.com", "https://binance.llamarpc.com"],
                   "gr": "bsc-mainnet", "llama": "bsc", "cid": 56},
    "polygon":    {"rpc": [env("POLYGON_RPC_URL"), "https://polygon-bor-rpc.publicnode.com", "https://polygon.llamarpc.com"],
                   "gr": "matic-mainnet", "llama": "polygon", "cid": 137},
    "arbitrum":   {"rpc": [env("ARB_RPC_URL"), "https://arbitrum-one-rpc.publicnode.com", "https://arbitrum.llamarpc.com"],
                   "gr": "arbitrum-mainnet", "llama": "arbitrum", "cid": 42161},
    "optimism":   {"rpc": [env("OP_RPC_URL"), "https://optimism-rpc.publicnode.com", "https://optimism.llamarpc.com"],
                   "gr": "optimism-mainnet", "llama": "optimism", "cid": 10},
    "base":       {"rpc": [env("BASE_RPC_URL"), "https://base-rpc.publicnode.com", "https://base.llamarpc.com"],
                   "gr": "base-mainnet", "llama": "base", "cid": 8453},
    "avalanche":  {"rpc": ["https://avalanche-c-chain-rpc.publicnode.com", "https://api.avax.network/ext/bc/C/rpc", "https://avalanche.drpc.org"],
                   "gr": "avax-mainnet", "llama": "avax", "cid": 43114},
    "fantom":     {"rpc": [env("FANTOM_RPC_URL"), "https://fantom-rpc.publicnode.com", "https://rpcapi.fantom.network", "https://fantom.drpc.org"],
                   "gr": "fantom-mainnet", "llama": "fantom", "cid": 250},
    "sei":        {"rpc": ["https://sei-evm-rpc.publicnode.com", "https://evm-rpc.sei-apis.com"],
                   "gr": "sei-mainnet", "llama": "sei", "cid": 1329},
    "mantle":     {"rpc": ["https://mantle-rpc.publicnode.com", "https://rpc.mantle.xyz"],
                   "gr": "mantle-mainnet", "llama": "mantle", "cid": 5000},
    "xdc":        {"rpc": ["https://erpc.xinfin.network", "https://rpc.xinfin.network"], "gr": None, "llama": "xdc", "cid": 50},
    "okc":        {"rpc": ["https://exchainrpc.okex.org"], "gr": None, "llama": "okexchain", "cid": 66},
    "kava":       {"rpc": ["https://kava-evm-rpc.publicnode.com", "https://evm.kava.io"], "gr": None, "llama": "kava", "cid": 2222},
    "moonriver":  {"rpc": [env("MOONRIVER_RPC_URL"), "https://moonriver.drpc.org", "https://rpc.api.moonriver.moonbeam.network", "https://moonriver.public.blastapi.io"],
                   "gr": None, "llama": "moonriver", "cid": 1285},
    "aurora":     {"rpc": ["https://aurora.drpc.org", "https://mainnet.aurora.dev"], "gr": None, "llama": "aurora", "cid": 1313161554},
    "astar":      {"rpc": ["https://evm.astar.network", "https://astar.public.blastapi.io"], "gr": None, "llama": "astar", "cid": 592},
    "polygon-zkevm": {"rpc": ["https://zkevm-rpc.com", "https://rpc.polygon-zkevm.gateway.fm"], "gr": None, "llama": "polygon_zkevm", "cid": 1101},
    "metis":      {"rpc": ["https://metis-rpc.publicnode.com", "https://andromeda.metis.io/?owner=1088"], "gr": None, "llama": "metis", "cid": 1088},
    "monad":      {"rpc": ["https://rpc.monad.xyz"], "gr": None, "llama": "monad", "cid": 143},
    "hyperliquid":{"rpc": ["https://rpc.hyperliquid.xyz/evm"], "gr": "hyperevm-mainnet", "llama": "hyperliquid", "cid": 999},
}
WORKING_RPC = {}

def rpc_preflight():
    def probe(item):
        ch, url = item
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
            req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=10) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return (ch, url, int(d["result"], 16))
        except Exception:
            pass
        return None
    items = [(ch, u) for ch, cfg in CHAINS.items() for u in cfg["rpc"] if u]
    with ThreadPoolExecutor(max_workers=24) as ex:
        for res in ex.map(probe, items):
            if res:
                ch, url, blk = res
                WORKING_RPC.setdefault(ch, []).append(url)
    return {ch: len(v) for ch, v in WORKING_RPC.items()}

def _urls(chain):
    return list(dict.fromkeys((WORKING_RPC.get(chain) or []) + [u for u in CHAINS[chain]["rpc"] if u]))

def rpc_call(chain, method, params, timeout=20):
    last = None
    for url in _urls(chain):
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d: return d["result"]
            last = d.get("error")
        except Exception as e:
            last = redact(e)
    raise RuntimeError(f"rpc fail {chain} {method}: {redact(last)}")

def rpc_batch(chain, calls, timeout=60):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for url in _urls(chain):
        try:
            req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item.get("result", {"error": item.get("error")})
                return out
            last = d
        except Exception as e:
            last = redact(e)
    raise RuntimeError(f"batch fail {chain}: {redact(last)}")

def get_block(chain):
    try:
        return int(rpc_call(chain, "eth_blockNumber", []), 16)
    except Exception:
        return None

# ---------------- GoldRush ----------------
GR_KEY = os.environ.get("GOLD_RUSH_API_KEY") or os.environ.get("GOLDRUSH_API_KEY")
_GR_LOCK = __import__("threading").Lock()
_GR_LAST = [0.0]
def _gr_throttle(min_interval=0.35):
    with _GR_LOCK:
        wait = _GR_LAST[0] + min_interval - time.time()
        if wait > 0:
            time.sleep(wait)
        _GR_LAST[0] = time.time()

def goldrush_balances(chain, addr, tries=3):
    cfg = CHAINS[chain]
    if not cfg.get("gr") or not GR_KEY:
        return {"error": "no-goldrush"}
    url = f"https://api.covalenthq.com/v1/{cfg['gr']}/address/{addr}/balances_v2/?key={GR_KEY}&nft=false&no-spam=true"
    last_detail = None
    for t in range(tries):
        try:
            _gr_throttle()
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read().decode())
            if d.get("error"):
                msg = str(d.get("error_message"))[:120]
                if "not supported" in msg.lower() or "support for chain" in msg.lower():
                    return {"error": "chain-unsupported"}
                time.sleep(2.0 * (t + 1)); continue
            data = d.get("data") or {}
            items = data.get("items") or []
            out = []
            total = 0.0
            for it in items:
                try:
                    dec = int(it.get("contract_decimals") or 0)
                    bal = int(it.get("balance") or 0) / (10 ** dec) if dec else float(it.get("balance") or 0)
                    usd = it.get("quote")
                    if usd is None and it.get("quote_rate") is not None:
                        usd = bal * float(it["quote_rate"])
                    usd = float(usd or 0)
                    sym = (it.get("contract_ticker_symbol") or "?")[:16]
                    if abs(usd) < 0.01 and bal == 0: continue
                    out.append({"symbol": sym, "contract": (it.get("contract_address") or "").lower(),
                                "balance": bal, "usd": round(usd, 2), "spam": bool(it.get("is_spam"))})
                    total += usd
                except Exception:
                    continue
            out.sort(key=lambda x: -x["usd"])
            return {"total_usd": round(total, 2), "items": out[:40]}
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(9 + 4 * t); continue
            last_detail = f"HTTP {e.code}"
            time.sleep(2.0 * (t + 1))
        except Exception as e:
            last_detail = type(e).__name__
            time.sleep(2.0 * (t + 1))
    return {"error": "goldrush-failed", "detail": last_detail}

# ---------------- llama prices ----------------
def llama_prices(chain, addrs):
    lc = CHAINS[chain].get("llama")
    if not lc or not addrs: return {}
    out = {}
    addrs = list(dict.fromkeys(a.lower() for a in addrs if a and a.startswith("0x")))
    for i in range(0, len(addrs), 80):
        chunk = addrs[i:i+80]
        try:
            url = "https://coins.llama.fi/prices/current/" + ",".join(f"{lc}:{a}" for a in chunk)
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode())
            for k, v in (d.get("coins") or {}).items():
                a = k.split(":")[-1].lower()
                if v.get("price") is not None:
                    out[a] = float(v["price"])
        except Exception:
            pass
    return out

SEL = {
    "allPairsLength()": "0x574f2ba3",
    "allPairs(uint256)": "0x1e3dd18b",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "getAllMarkets()": "0xb0772d0b",
    "getAllProtocolAddresses()": "0xea7579d1",
    "getProtocolDetails()": "0x8080425b",
    "getSdtStakings(uint256,uint256)": "0x315c6359",
    "getGlobalViewCvgSdtStaking(address)": "0xc9df4f3d",
    "getNextPositionId()": "0x067f4ddd",
    "getPositionValue(uint256)": "0xb86a0aaa",
    "underlying()": "0x6f307dc3",
    "asset()": "0x38d52e0f",
    "totalAssets()": "0x01e1d114",
    "want()": "0x1f1fcd51",
    "token()": "0xfc0c546a",
    "staking_token()": "0x2dc7d74c",
    "getLendingPool()": "0x0261bf8b",
    "getPool()": "0x026b1d5f",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "totalSupply()": "0x18160ddd",
    "balanceOf(address)": "0x70a08231",
}

def encode_uint(n):
    return hex(n)[2:].rjust(64, "0")

def encode_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def eth_call(chain, to, data):
    return rpc_call(chain, "eth_call", [{"to": to, "data": data}, "latest"])

def hex_to_int(h):
    try:
        return int(h, 16)
    except Exception:
        return None

def decode_addr(h):
    if not h or not isinstance(h, str) or len(h) < 42: return None
    return "0x" + h[-40:]

def decode_string(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], "big")
            return b[64:64+ln].decode("utf-8", "replace")
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None

def main():
    os.makedirs(OUT, exist_ok=True)
    for sub in ("rpc", "goldrush", "factories", "special"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    targets = json.load(open(os.path.join(BASE, os.environ.get("L2_TARGETS", "analysis/targets.json"))))
    core = {}
    cpath = os.path.join(BASE, "analysis/coreAssets.json")
    if os.path.exists(cpath):
        core = json.load(open(cpath))
    CORE_KEY = {"xdc": "xdc", "okc": "okexchain", "kava": "kava", "moonriver": "moonriver",
                "aurora": "aurora", "astar": "astar", "polygon-zkevm": "polygon_zkevm",
                "metis": "metis", "monad": "monad", "hyperliquid": "hyperliquid",
                "avalanche": "avax", "sei": "sei", "mantle": "mantle"}

    pf = rpc_preflight()
    print("rpc preflight:", pf, flush=True)

    blocks = {}
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(get_block, c): c for c in CHAINS}
        for f in as_completed(futs):
            c = futs[f]
            try: blocks[c] = f.result()
            except Exception: blocks[c] = None
    json.dump(blocks, open(os.path.join(OUT, "blocks.json"), "w"), indent=1)
    print("blocks:", {k: v for k, v in blocks.items() if v}, flush=True)

    probes = []
    seen = set()
    for t in targets:
        for a in t["addresses"]:
            for ch in (t["probe_chains"] or []):
                k = (ch, a["addr"])
                if k in seen: continue
                seen.add(k)
                probes.append({"slug": t["slug"], "chain": ch, "addr": a["addr"], "roles": a["roles"]})
    print(f"probes: {len(probes)}", flush=True)

    by_chain = {}
    for p in probes:
        by_chain.setdefault(p["chain"], []).append(p)
    live = []
    for ch, plist in by_chain.items():
        addrs = [p["addr"] for p in plist]
        for i in range(0, len(addrs), 60):
            chunk = addrs[i:i+60]
            calls = [("eth_getCode", [a, "latest"]) for a in chunk]
            try:
                res = rpc_batch(ch, calls)
            except Exception as e:
                print("code-batch fail", ch, redact(e), flush=True)
                res = [None] * len(chunk)
            for a, r in zip(chunk, res):
                if r and r != "0x" and not isinstance(r, dict):
                    for p in plist:
                        if p["addr"] == a:
                            live.append(p); break
    print(f"contracts with code: {len(live)}", flush=True)

    results = []

    def probe_one(p):
        ch, a, slug = p["chain"], p["addr"], p["slug"]
        rec = {"slug": slug, "chain": ch, "addr": a, "roles": p["roles"]}
        try:
            rec["native_wei"] = rpc_call(ch, "eth_getBalance", [a, "latest"])
        except Exception:
            rec["native_wei"] = None
        # batched getters
        g = {}
        getter_defs = [("underlying", SEL["underlying()"]), ("asset", SEL["asset()"]),
                       ("totalAssets", SEL["totalAssets()"]), ("want", SEL["want()"]),
                       ("token", SEL["token()"]), ("staking_token", SEL["staking_token()"]),
                       ("property", "0x176fd3f0"), ("stakingToken", "0x72f702f3"),
                       ("lpToken", "0x5fcbd285"), ("underlyingToken", "0x2495a599"),
                       ("coin", "0x11df9995"), ("getToken", "0x21df0da7"),
                       ("decimals", SEL["decimals()"]), ("symbol", SEL["symbol()"]),
                       ("totalSupply", SEL["totalSupply()"])]
        try:
            rs = rpc_batch(ch, [("eth_call", [{"to": a, "data": sel}, "latest"]) for _, sel in getter_defs], timeout=45)
        except Exception:
            rs = [None] * len(getter_defs)
        for (name, _), r in zip(getter_defs, rs):
            if not isinstance(r, str) or r == "0x" or len(r) < 3: continue
            if name in ("underlying", "asset", "want", "token", "staking_token", "property",
                        "stakingToken", "lpToken", "underlyingToken", "coin", "getToken"):
                v = decode_addr(r)
                if v and v != "0x0000000000000000000000000000000000000000": g[name] = v
            elif name == "symbol":
                v = decode_string(r)
                if v: g[name] = v
            else:
                v = hex_to_int(r)
                if v is not None: g[name] = str(v)
        rec["getters"] = g
        # follow provider-style contracts (Aave forks)
        follow = {}
        for fname, fsel in (("lendingPool", SEL["getLendingPool()"]), ("pool", SEL["getPool()"])):
            try:
                r = eth_call(ch, a, fsel)
                v = decode_addr(r)
                if v and v != "0x0000000000000000000000000000000000000000":
                    follow[fname] = v
            except Exception:
                pass
        if follow:
            rec["follow"] = follow
            for fname, v in follow.items():
                rec[f"follow_{fname}_goldrush"] = goldrush_balances(ch, v)
        # GoldRush (best-effort)
        rec["goldrush"] = goldrush_balances(ch, a)
        # RPC token scan (ALWAYS — primary CI evidence; GoldRush may be unavailable from CI IPs)
        ck = CORE_KEY.get(ch, ch)
        toks = dict((core.get(ck) or {}))
        # add getter-resolved tokens
        for gname in ("asset", "token", "underlying", "want", "staking_token", "property",
                      "stakingToken", "lpToken", "underlyingToken", "coin", "getToken"):
            v = g.get(gname)
            if v: toks[f"resolved_{gname}"] = v
        tok_addrs = [v.lower() for v in toks.values() if isinstance(v, str) and len(v) == 42]
        tok_addrs = list(dict.fromkeys(tok_addrs))[:200]
        found = []
        for i in range(0, len(tok_addrs), 80):
            chunk = tok_addrs[i:i+80]
            calls = [("eth_call", [{"to": t, "data": SEL["balanceOf(address)"] + encode_addr(a)}, "latest"]) for t in chunk]
            try:
                rs = rpc_batch(ch, calls)
            except Exception:
                rs = [None] * len(chunk)
            for t, r in zip(chunk, rs):
                v = hex_to_int(r) if isinstance(r, str) else None
                if v: found.append((t, v))
        if found:
            prices = llama_prices(ch, [t for t, _ in found])
            items = []
            total = 0.0
            decs = {}
            try:
                drs = rpc_batch(ch, [("eth_call", [{"to": t, "data": SEL["decimals()"]}, "latest"]) for t, _ in found])
                for (t, _), r in zip(found, drs):
                    d = hex_to_int(r) if isinstance(r, str) else None
                    decs[t] = d if d is not None and 0 <= d <= 36 else 18
            except Exception:
                pass
            for t, v in found:
                d = decs.get(t, 18)
                bal = v / 10 ** d
                usd = bal * prices.get(t, 0)
                total += usd
                items.append({"symbol": "?", "contract": t, "balance": bal, "usd": round(usd, 2), "spam": False})
            items.sort(key=lambda x: -x["usd"])
            rec["rpc_token_scan"] = {"total_usd": round(total, 2), "n_nonzero": len(items), "items": items[:30]}
        return rec

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(probe_one, p): p for p in live}
        for i, f in enumerate(as_completed(futs)):
            try:
                rec = f.result()
            except Exception as e:
                p = futs[f]; rec = {"slug": p["slug"], "chain": p["chain"], "addr": p["addr"], "error": redact(e)}
            results.append(rec)
            if (i + 1) % 25 == 0:
                print(f"probed {i+1}/{len(live)} ({time.time()-t0:.0f}s)", flush=True)
    json.dump(results, open(os.path.join(OUT, "probe-results.json"), "w"), indent=1)
    print(f"probe done: {len(results)}", flush=True)

    # factories
    fac_out = {}
    factories = [(p["slug"], p["chain"], p["addr"]) for p in live
                 if any(r == "factory" for r in p["roles"])]
    factories = list({(s, c, a): (s, c, a) for s, c, a in factories}.values())
    print(f"factories: {len(factories)}", flush=True)

    def enum_factory(slug, ch, addr):
        rec = {"slug": slug, "chain": ch, "factory": addr}
        try:
            n = hex_to_int(eth_call(ch, addr, SEL["allPairsLength()"]))
            if not n:
                rec["error"] = "no-allPairsLength"
                return rec
            rec["n_pairs"] = n
            idxs = list(range(min(n, 1200)))
            if n > 1200:
                step = max(1, n // 1200)
                idxs = list(range(0, n, step))[:1200]
            pairs = []
            for i in range(0, len(idxs), 100):
                chunk = idxs[i:i+100]
                calls = [("eth_call", [{"to": addr, "data": SEL["allPairs(uint256)"] + encode_uint(x)}, "latest"]) for x in chunk]
                try:
                    rs = rpc_batch(ch, calls)
                except Exception:
                    rs = [None] * len(chunk)
                for r in rs:
                    a2 = decode_addr(r) if isinstance(r, str) else None
                    if a2: pairs.append(a2)
            rec["pairs_sampled"] = len(pairs)
            res = []
            toks = []
            for i in range(0, len(pairs), 60):
                chunk = pairs[i:i+60]
                calls = []
                for pa in chunk:
                    calls.append(("eth_call", [{"to": pa, "data": SEL["token0()"]}, "latest"]))
                for pa in chunk:
                    calls.append(("eth_call", [{"to": pa, "data": SEL["token1()"]}, "latest"]))
                for pa in chunk:
                    calls.append(("eth_call", [{"to": pa, "data": SEL["getReserves()"]}, "latest"]))
                try:
                    rs = rpc_batch(ch, calls, timeout=90)
                except Exception:
                    rs = [None] * len(calls)
                L = len(chunk)
                for j, pa in enumerate(chunk):
                    t0_ = decode_addr(rs[j]) if isinstance(rs[j], str) else None
                    t1_ = decode_addr(rs[L + j]) if isinstance(rs[L + j], str) else None
                    rr = rs[2 * L + j] if isinstance(rs[2 * L + j], str) else None
                    if t0_ and t1_ and rr and len(rr) >= 130:
                        r0 = int(rr[2:66], 16); r1 = int(rr[66:130], 16)
                        toks.extend([t0_, t1_])
                        res.append((pa, t0_, t1_, r0, r1))
            toks = list(dict.fromkeys(toks))
            prices = llama_prices(ch, toks)
            dec = {}
            for i in range(0, len(toks), 100):
                chunk = toks[i:i+100]
                calls = [("eth_call", [{"to": x, "data": SEL["decimals()"]}, "latest"]) for x in chunk]
                try:
                    rs = rpc_batch(ch, calls)
                except Exception:
                    rs = [None] * len(chunk)
                for x, r in zip(chunk, rs):
                    d = hex_to_int(r) if isinstance(r, str) else None
                    dec[x] = d if d is not None and 0 <= d <= 36 else 18
            total = 0.0; top = []
            for pa, t0_, t1_, r0, r1 in res:
                v0 = r0 / 10 ** dec.get(t0_, 18) * prices.get(t0_, 0)
                v1 = r1 / 10 ** dec.get(t1_, 18) * prices.get(t1_, 0)
                usd = v0 + v1
                total += usd
                top.append({"pair": pa, "usd": round(usd, 2)})
            top.sort(key=lambda x: -x["usd"])
            rec["sampled_usd"] = round(total, 2)
            rec["top_pairs"] = top[:10]
            rec["scale"] = n / max(1, len(pairs))
            rec["est_total_usd"] = round(total * rec["scale"], 2)
            rec["unpriced_tokens"] = [t for t in toks if t not in prices][:10]
        except Exception as e:
            rec["error"] = redact(e)
        return rec

    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(enum_factory, s, c, a): (s, c, a) for s, c, a in factories}
        for f in as_completed(futs):
            s, c, a = futs[f]
            try: rec = f.result()
            except Exception as e: rec = {"slug": s, "chain": c, "factory": a, "error": redact(e)}
            fac_out[f"{s}|{c}|{a}"] = rec
            print("factory", s, c, rec.get("est_total_usd", rec.get("error")), flush=True)
    json.dump(fac_out, open(os.path.join(OUT, "factories.json"), "w"), indent=1)

    # special handlers
    special = {}
    def add_special(slug, key, val):
        special.setdefault(slug, {})[key] = val

    # cover-protocol
    try:
        fac = "0xedfc81bf63527337cd2193925f9c0cf2d537acca"
        r = eth_call("ethereum", fac, SEL["getAllProtocolAddresses()"])
        protos = []
        if isinstance(r, str) and len(r) > 130:
            b = r[2:]
            off = int(b[0:64], 16)
            n = int(b[off*2:off*2+64], 16)
            for i in range(min(n, 60)):
                protos.append("0x" + b[off*2+64+i*64+24: off*2+64+i*64+64])
        covers = []
        for pr in protos[:40]:
            try:
                rr = eth_call("ethereum", pr, SEL["getProtocolDetails()"])
                if isinstance(rr, str) and len(rr) > 1000:
                    b = rr[2:]
                    o = int(b[7*64:8*64], 16)
                    ln = int(b[o*2: o*2+64], 16)
                    for k in range(min(ln, 40)):
                        covers.append("0x" + b[o*2+64 + k*64 + 24: o*2+64 + k*64 + 64])
            except Exception:
                pass
        covers = list(dict.fromkeys(covers))
        add_special("cover-protocol", "n_protocols", len(protos))
        add_special("cover-protocol", "n_covers", len(covers))
        bal = {}
        for c in covers[:60]:
            bal[c] = goldrush_balances("ethereum", c)
        add_special("cover-protocol", "cover_balances", bal)
    except Exception as e:
        add_special("cover-protocol", "error", redact(e))

    # convergence-fi
    try:
        tower = "0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7"
        viewer = "0xA3A8cDA21f50b6737385E46FC9495a9998B05Ff0"
        r = eth_call("ethereum", tower, SEL["getSdtStakings(uint256,uint256)"] + encode_uint(0) + encode_uint(120))
        stakings = []
        if isinstance(r, str) and len(r) > 130:
            b = r[2:]
            array_start = int(b[0:64], 16)
            off_base = array_start + 32
            n = int(b[array_start*2:array_start*2+64], 16)
            for i in range(min(n, 120)):
                off_i = int(b[(off_base+i*32)*2:(off_base+i*32)*2+64], 16)
                tb = off_base + off_i
                stakings.append("0x" + b[tb*2+24:tb*2+64])
        add_special("convergence-fi", "n_stakings", len(stakings))
        cvgsdts = []
        for s in stakings[:60]:
            try:
                rr = eth_call("ethereum", viewer, SEL["getGlobalViewCvgSdtStaking(address)"] + encode_addr(s))
                if isinstance(rr, str) and len(rr) >= 128:
                    cvgsdts.append("0x" + rr[2:66][24:64])
            except Exception:
                pass
        cvgsdts = list(dict.fromkeys(cvgsdts))
        add_special("convergence-fi", "n_cvgsdt", len(cvgsdts))
        bal = {}
        for c in cvgsdts[:60]:
            bal[c] = goldrush_balances("ethereum", c)
        add_special("convergence-fi", "cvgSdt_balances", bal)
    except Exception as e:
        add_special("convergence-fi", "error", redact(e))

    # comptrollers
    compt = [(p["slug"], p["chain"], p["addr"]) for p in live if "comptroller" in p["roles"]]
    for slug, ch, addr in list({(s, c, a): (s, c, a) for s, c, a in compt}.values()):
        try:
            r = eth_call(ch, addr, SEL["getAllMarkets()"])
            markets = []
            if isinstance(r, str) and len(r) > 130:
                b = r[2:]
                n = int(b[64:128], 16)
                for i in range(min(n, 60)):
                    markets.append("0x" + b[128 + i*64 + 24: 128 + i*64 + 64])
            mbal = {}
            for m in markets:
                mbal[m] = goldrush_balances(ch, m)
            add_special(slug, f"comptroller_{ch}_{addr}",
                        {"n_markets": len(markets), "markets": markets, "balances": mbal})
        except Exception as e:
            add_special(slug, f"comptroller_{ch}_{addr}", {"error": redact(e)})

    # blueberry bank (ethereum)
    try:
        bank = "0xa34f59f634d48e2c3606048f2367326c46a4b5fa"
        n = hex_to_int(eth_call("ethereum", bank, SEL["getNextPositionId()"]))
        tot = 0.0; vals = []
        ids = list(range(min(n or 0, 400)))
        for i in range(0, len(ids), 50):
            chunk = ids[i:i+50]
            calls = [("eth_call", [{"to": bank, "data": SEL["getPositionValue(uint256)"] + encode_uint(x)}, "latest"]) for x in chunk]
            try:
                rs = rpc_batch("ethereum", calls)
            except Exception:
                rs = [None] * len(chunk)
            for r in rs:
                v = hex_to_int(r) if isinstance(r, str) else None
                if v: tot += v / 1e18; vals.append(v / 1e18)
        add_special("blueberry", "bank_positions", {"n": n, "sum_usd_est": round(tot, 2), "sample": vals[:20]})
    except Exception as e:
        add_special("blueberry", "bank_error", redact(e))

    # API probes
    apis = {
        "hord": ("GET", "https://api.hord.app/validators/stats/latest", None),
        "defiedge": ("POST", "https://api.defiedge.io/graphql", {"query": "query { stats(network: [mainnet]) { totalValueManaged } }"}),
        "picnic": ("POST", "https://www.usepicnic.com/api/get-portfolios", {"pageIndex": 0, "sortBy": "pnl", "nameQuery": "", "filterValue": 10, "nftIds": None, "filterCategory": []}),
        "stakehouse-lsd": ("POST", "https://lsd-subgraph.joinstakehouse.com", {"query": "{ lptokens(first: 5) { id } }"}),
        "stakehouse-core": ("POST", "https://stakehouse-subgraph.joinstakehouse.com", {"query": "{ stakehouseAccounts(first: 5) { id } }"}),
        "kinetix-kava": ("POST", "https://kava-graph-node.metavault.trade/subgraphs/name/kinetixfi/v3-subgraph", {"query": "{ factories(first: 1) { id poolCount } }"}),
        "kinetix-base": ("POST", "https://api.studio.thegraph.com/query/55804/kinetixfi-base-v3/version/latest", {"query": "{ factories(first: 1) { id poolCount } }"}),
    }
    for name, (meth, url, body) in apis.items():
        try:
            data = json.dumps(body).encode() if body is not None else None
            req = urllib.request.Request(url, data=data, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=25) as r:
                txt = r.read().decode("utf-8", "replace")[:2000]
            special.setdefault("_api-probes", {})[name] = {"alive": True, "resp": txt[:600]}
        except Exception as e:
            special.setdefault("_api-probes", {})[name] = {"alive": False, "err": redact(e)}

    # silostake sei cosmwasm
    try:
        hub = "sei1e3gttzq5e5k49f9f5gzvrl0rltlav65xu6p9xc0aj7e84lantdjqp7cncc"
        q = base64.b64encode(json.dumps({"state": {}}).encode()).decode()
        url = f"https://rest.sei-apis.com/cosmwasm/wasm/v1/contract/{hub}/smart/{q}"
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=25) as r:
            txt = r.read().decode()[:800]
        special.setdefault("_api-probes", {})["silostake-sei"] = {"alive": True, "resp": txt}
    except Exception as e:
        special.setdefault("_api-probes", {})["silostake-sei"] = {"alive": False, "err": redact(e)}

    json.dump(special, open(os.path.join(OUT, "special.json"), "w"), indent=1)
    print("special handlers done", flush=True)

    # rollup
    roll = {}
    for rec in results:
        key = rec["slug"]
        r = roll.setdefault(key, {"chains": {}})
        ch = r["chains"].setdefault(rec["chain"], {"addrs": 0, "usd_total": 0.0, "top": []})
        ch["addrs"] += 1
        gr = rec.get("goldrush") or {}
        if "total_usd" in gr:
            ch["usd_total"] += gr["total_usd"]
            for it in gr["items"][:5]:
                if it["usd"] > 0:
                    ch["top"].append({"addr": rec["addr"], **it})
        rts = rec.get("rpc_token_scan") or {}
        if rts.get("total_usd"):
            ch["usd_total"] += rts["total_usd"]
            for it in rts.get("items", [])[:5]:
                if it["usd"] > 0:
                    ch["top"].append({"addr": rec["addr"], **it})
        for fname in ("lendingPool", "pool"):
            fgr = rec.get(f"follow_{fname}_goldrush") or {}
            if "total_usd" in fgr:
                ch["usd_total"] += fgr["total_usd"]
                for it in fgr["items"][:5]:
                    if it["usd"] > 0:
                        ch["top"].append({"addr": rec["addr"] + "->" + fname, **it})
    for k, v in fac_out.items():
        s = v["slug"]
        roll.setdefault(s, {"chains": {}})
        r = roll[s]["chains"].setdefault(v["chain"], {"addrs": 0, "usd_total": 0.0, "top": []})
        if "est_total_usd" in v:
            r.setdefault("factories", []).append({"factory": v["factory"], "n_pairs": v.get("n_pairs"),
                                                  "est_usd": v.get("est_total_usd"), "top": v.get("top_pairs", [])[:5]})
    json.dump(roll, open(os.path.join(OUT, "rollup.json"), "w"), indent=1)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
