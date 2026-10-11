#!/usr/bin/env python3
"""
l2-triage-b — Phase-1 custody screen for alt-EVM/L2 protocols.
Reads live on-chain balances of core custody contracts via KEYLESS public RPCs.
Outputs: ci-out/results.json, ci-out/summary.csv, ci-out/run.log
Read-only: only eth_call / eth_getLogs / eth_blockNumber / eth_getCode.
"""
import json, os, sys, time, re, threading, subprocess, urllib.request, urllib.error, csv
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PLAN = json.load(open(os.path.join(HERE, "plan.json")))
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "run.log"), "a", buffering=1)


def log(*a):
    m = " ".join(str(x) for x in a)
    print(m, flush=True)
    LOG.write(m + "\n")


# ---------------------------------------------------------------- selectors
SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "decimals": "0x313ce567",
    "balanceOf": "0x70a08231",
    "getAllMarkets": "0xb0772d0b",
    "underlying": "0x6f307dc3",
    "totalBorrows": "0x47bd3718",
    "totalReserves": "0x8f840ddd",
    "exchangeRateStored": "0x182df0f5",
    "activePool": "0x7f7dde4a",
    "defaultPool": "0x3cc74225",
    "underlyingToken": "0x2495a599",
    "poolLength": "0x081e3eda",
    "poolInfo": "0x1526fe27",
    "SY": "0xafd27bf5",
    "assetInfo": "0xa40bee50",
    "exchangeRate": "0x3ba0b9a9",
    "symbol": "0x95d89b41",
}
V3_TOPIC = "0x783cca1c0412dd0d695e784568c96da2e9c22ff989357a2e8b1d9b2b4e6b7118"
ALG_TOPIC = "0x91ccaa7a278130b65168c3a0c8d3bcae84cf5e43704342bd3ec0b59e59c036db"
SPLICE_TOPIC = "0xae811fae25e2770b6bd1dcb1475657e8c3a976f91d1ebf081271db08eef920af"
COG_TOPICS = [
    "0xcee3ea07e366d1803a75ad9db5b48db815396a0509effa9144f11b1488fd0d88",  # StablePairCreated
    "0x402ac5214013377f8188ee4bd9ae414578846daef1bcd1fc81046d7532a4db26",  # LowPairCreated
    "0x577ff9aeebc61c0b7532654ed335c2841ad013ab40b6437676f9efa253dec450",  # MediumPairCreated
    "0x2967c7aae5a8969b84bbb879d4fac4a15c2efa49bae21d091f645383d43cd56f",  # HighPairCreated
]
NULL = "0x0000000000000000000000000000000000000000"
NULLS = {NULL, "0x" + "0" * 64}

ETHERSCAN_CHAINID = {
    "linea": 59144, "blast": 81457, "scroll": 534352, "mode": 34443, "fraxtal": 252,
    "xdai": 100, "celo": 42220, "era": 324, "polygon_zkevm": 1101, "base": 8453,
    "manta": 169, "op_bnb": 204,
}
ES_KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
MAX_PAIRS = int(os.environ.get("L2B_MAX_PAIRS", "800"))
MAX_POOLS = int(os.environ.get("L2B_MAX_POOLS", "3500"))
OUT_NAME = os.environ.get("L2B_OUT", "results.json")
MAX_LOGS_CALLS = 3500

# ---------------------------------------------------------------- utils
class RangeError(Exception):
    pass


def words(hexstr):
    h = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return [h[i:i + 64] for i in range(0, len(h) - 63, 64)]


def dec_addr(word):
    return "0x" + word[-40:]


def dec_uint(word):
    return int(word, 16)


def pad_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def pad_uint(n):
    return hex(int(n))[2:].rjust(64, "0")


class Chain:
    def __init__(self, name, url, call_urls=None):
        self.name = name
        self.url = url
        self.call_urls = call_urls or [url]
        self._lock = threading.Lock()
        self._last = 0.0
        self._url_i = 0
        self.block = None
        self.fatal = None

    def _throttle(self):
        with self._lock:
            dt = time.time() - self._last
            if dt < 0.02:
                time.sleep(0.02 - dt)
            self._last = time.time()

    def _next_url(self):
        with self._lock:
            u = self.call_urls[self._url_i % len(self.call_urls)]
            self._url_i += 1
            return u

    def call(self, method, params, tries=6, timeout=45, url=None):
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
        last = None
        for i in range(tries):
            self._throttle()
            u = url or self._next_url()
            try:
                req = urllib.request.Request(u, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    d = json.loads(r.read().decode())
                if "result" in d:
                    return d["result"]
                err = d.get("error") or {}
                msg = str(err.get("message", err))
                if re.search(r"range|limit|too large|exceeds", msg, re.I):
                    raise RangeError(msg)
                last = msg
                time.sleep(0.4 + 0.4 * i)
            except RangeError:
                raise
            except urllib.error.HTTPError as e:
                if e.code == 413:
                    raise RangeError("http 413 request entity too large")
                last = f"http {e.code}"
                time.sleep(0.3 + 0.3 * i)
            except Exception as e:
                last = str(e)
                time.sleep(0.5 + 0.5 * i)
        raise RuntimeError(f"{self.name} rpc failed: {method}: {last}")

    def eth_call(self, to, data, block="latest"):
        return self.call("eth_call", [{"to": to, "data": data}, block])

    def block_number(self):
        if self.block is None:
            last = None
            for u in list(self.call_urls) + [self.url]:
                try:
                    self.block = int(self.call("eth_blockNumber", [], tries=3, url=u), 16)
                    return self.block
                except Exception as e:
                    last = e
            raise RuntimeError(f"{self.name} blockNumber failed: {last}")
        return self.block

    def get_code(self, addr):
        return self.call("eth_getCode", [addr, "latest"])


_callpref = PLAN.get("rpc_call_pref", {})


def _call_urls(name, url):
    v = _callpref.get(name)
    if not v:
        return [url]
    return v if isinstance(v, list) else [v]


CHAINS = {name: Chain(name, url, _call_urls(name, url)) for name, url in PLAN["rpcs"].items()}
PC = PLAN["price_chain"]
NATIVE_CG = PLAN["native_cg"]

_dec_cache = {}
_dec_lock = threading.Lock()


def get_decimals(chain, token):
    key = (chain.name, token.lower())
    with _dec_lock:
        if key in _dec_cache:
            return _dec_cache[key]
    try:
        d = dec_uint(words(chain.eth_call(token, SEL["decimals"]))[0])
        if d > 36:
            d = 18
    except Exception:
        d = 18
    with _dec_lock:
        _dec_cache[key] = d
    return d


ASSETS = []          # {chain_key, token, amount, dec, target_id, label, src}
ASSETS_LOCK = threading.Lock()


def add_asset(chain, token, raw_amount, target, src=""):
    if raw_amount is None or raw_amount == 0:
        return
    token_l = token.lower()
    if token_l in NULLS:
        dec = 18
        tok = NULL
    else:
        dec = get_decimals(chain, token)
        tok = token_l
    with ASSETS_LOCK:
        ASSETS.append({"chain": PC.get(chain.name, chain.name), "token": tok,
                       "amount": float(raw_amount) / (10 ** dec), "dec": dec,
                       "target": target["_id"], "label": target["label"], "src": src,
                       "raw": str(raw_amount)})


def bal(chain, token, owner):
    try:
        if token.lower() in NULLS:
            return int(chain.call("eth_getBalance", [owner, "latest"]), 16)
        r = chain.eth_call(token, SEL["balanceOf"] + pad_addr(owner))
        return dec_uint(words(r)[0]) if r and r != "0x" else 0
    except Exception:
        return 0


def bal_many(chain, token, owners, pool=None):
    out = {}
    if pool is None:
        pool = ThreadPoolExecutor(max_workers=10)
        own_pool = True
    else:
        own_pool = False
    futs = {pool.submit(bal, chain, token, o): o for o in owners}
    for f in as_completed(futs):
        try:
            out[futs[f]] = f.result()
        except Exception:
            out[futs[f]] = 0
    if own_pool:
        pool.shutdown()
    return out


# ---------------------------------------------------------------- getLogs
def _rpc_get_logs_one(chain, address, topics, from_block, to_block, initial=10_000_000):
    size = initial
    probe_ok = False
    while size >= 1000:
        try:
            chain.call("eth_getLogs", [{"address": address, "topics": [topics],
                                        "fromBlock": hex(from_block),
                                        "toBlock": hex(min(from_block + size - 1, to_block))}])
            probe_ok = True
            break
        except RangeError:
            size //= 2
    if not probe_ok:
        raise RangeError("getLogs chunk size below 1000 blocks")
    logs = []
    lock = threading.Lock()

    def fetch(st):
        en = min(st + size - 1, to_block)
        r = chain.call("eth_getLogs", [{"address": address, "topics": [topics],
                                        "fromBlock": hex(st), "toBlock": hex(en)}])
        with lock:
            logs.extend(r)

    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(fetch, range(from_block, to_block + 1, size)))
    return logs


def rpc_get_logs(chain_name, address, topics, from_block, to_block, initial=10_000_000):
    urls = PLAN.get("rpc_fallbacks", {}).get(chain_name) or [PLAN["rpcs"][chain_name]]
    last = None
    for url in urls:
        ch = Chain(chain_name, url)
        try:
            ch.block_number()
            return _rpc_get_logs_one(ch, address, topics, from_block, to_block, initial)
        except RangeError as e:
            last = e
            continue
    raise RangeError(f"all rpcs failed for getLogs: {last}")


def etherscan_logs(chain, address, topic0, from_block, to_block):
    cid = ETHERSCAN_CHAINID.get(chain.name)
    if not cid or not ES_KEY:
        return None
    out = []
    page = 1
    while True:
        url = (f"https://api.etherscan.io/v2/api?chainid={cid}&module=logs&action=getLogs"
               f"&address={address}&topic0={topic0}&fromBlock={from_block}&toBlock={to_block}"
               f"&page={page}&offset=1000&apikey={ES_KEY}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read().decode())
        except Exception as e:
            log(f"  [etherscan] {chain.name} {address} error {e}")
            return None
        if str(d.get("status")) == "1" and isinstance(d.get("result"), list):
            out.extend(d["result"])
            if len(d["result"]) < 1000:
                return out
            page += 1
            time.sleep(0.25)
        elif "No logs found" in str(d.get("message", "")) or d.get("result") == []:
            return out
        else:
            log(f"  [etherscan] {chain.name} {address} status={d.get('status')} msg={str(d.get('message'))[:80]}")
            return out if out else None


def get_logs(chain, address, topics, from_block, to_block):
    """topics: list of topic0 alternatives (OR). Returns logs or raises."""
    block = chain.block_number()
    try:
        return rpc_get_logs(chain.name, address, topics, from_block, to_block)
    except RangeError:
        if chain.name in ETHERSCAN_CHAINID:
            all_logs = []
            for t0 in topics:
                r = etherscan_logs(chain, address, t0, from_block, block)
                if r is None:
                    all_logs = None
                    break
                all_logs.extend(r)
            if all_logs:
                return all_logs
        raise


def log_args(entry):
    return [t["topics"] for t in entry]


# ---------------------------------------------------------------- handlers
def h_uni_v2(chain, t, res):
    factory = t["factory"]
    code = chain.get_code(factory)
    if code in ("0x", "0x0", None):
        res["note"] = "factory has no code"
        return
    n = dec_uint(words(chain.eth_call(factory, SEL["allPairsLength"]))[0])
    res["pair_count"] = n
    if n == 0:
        return
    cap = min(n, MAX_PAIRS)
    if cap < n:
        res["note"] = f"capped at {cap}/{n} pairs"
    pool = ThreadPoolExecutor(max_workers=12)
    idx = list(range(cap))
    if n > cap:
        idx += list(range(max(0, n - 200), n))
    pair_addrs = []
    futs = [pool.submit(lambda i=i: dec_addr(words(chain.eth_call(factory, SEL["allPairs"] + pad_uint(i)))[0])) for i in idx]
    for f in as_completed(futs):
        try:
            pair_addrs.append(f.result())
        except Exception:
            pass
    pair_addrs = [p for p in pair_addrs if p.lower() != NULL]
    res["pairs_scanned"] = len(pair_addrs)

    def scan(pair):
        out = {"pair": pair}
        try:
            t0 = dec_addr(words(chain.eth_call(pair, SEL["token0"]))[0])
            t1 = dec_addr(words(chain.eth_call(pair, SEL["token1"]))[0])
            b0 = bal(chain, t0, pair)
            b1 = bal(chain, t1, pair)
            out.update({"t0": t0, "t1": t1, "b0": b0, "b1": b1})
        except Exception as e:
            out["err"] = str(e)[:80]
        return out

    rows = []
    _t0 = time.time()
    deadline = _t0 + 900
    partial = False
    for i, f in enumerate(as_completed([pool.submit(scan, p) for p in pair_addrs])):
        rows.append(f.result())
        if i and i % 500 == 0:
            log(f"      ..{i}/{len(pair_addrs)} pairs scanned ({int(time.time()-_t0)}s)")
        if time.time() > deadline:
            partial = True
            break
    pool.shutdown(wait=False, cancel_futures=True)
    if partial:
        res["note"] = (res.get("note", "") + f" partial: {len(rows)}/{len(pair_addrs)} pairs (timeout)").strip()
    res["pairs"] = rows
    for r in rows:
        if "b0" in r:
            add_asset(chain, r["t0"], r["b0"], t, f"pair {r['pair']}")
            add_asset(chain, r["t1"], r["b1"], t, f"pair {r['pair']}")


def h_uni_v3(chain, t, res):
    factory = t["factory"]
    code = chain.get_code(factory)
    if code in ("0x", "0x0", None):
        res["note"] = "factory has no code"
        return
    fb = t.get("from_block", 0)
    logs = get_logs(chain, factory, [V3_TOPIC, ALG_TOPIC], fb, chain.block_number())
    res["log_count"] = len(logs)
    pool_tokens = {}
    for lg in logs:
        topics = lg.get("topics") or []
        data = lg.get("data", "0x")
        t0 = t1 = None
        pool = None
        if topics and topics[0].lower() == V3_TOPIC.lower():
            if len(topics) >= 3:
                t0 = dec_addr(topics[1])
                t1 = dec_addr(topics[2])
            ws = words(data)
            if len(ws) >= 2:
                pool = dec_addr(ws[1])
        elif topics and topics[0].lower() == ALG_TOPIC.lower():
            if len(topics) >= 3:
                t0 = dec_addr(topics[1])
                t1 = dec_addr(topics[2])
            ws = words(data)
            if ws:
                pool = dec_addr(ws[0])
            elif len(topics) >= 4:
                pool = dec_addr(topics[3])
        if pool and pool.lower() != NULL:
            pool_tokens[pool] = (t0, t1)
    pools = list(pool_tokens.keys())
    res["pool_count"] = len(pools)
    if len(pools) > MAX_POOLS:
        res["note"] = f"capped at {MAX_POOLS}/{len(pools)} pools"
        pools = pools[:MAX_POOLS]
    pool = ThreadPoolExecutor(max_workers=16)

    def scan(p):
        out = {"pool": p}
        try:
            t0, t1 = pool_tokens[p]
            if not t0 or not t1:
                t0 = dec_addr(words(chain.eth_call(p, SEL["token0"]))[0])
                t1 = dec_addr(words(chain.eth_call(p, SEL["token1"]))[0])
            out.update({"t0": t0, "t1": t1, "b0": bal(chain, t0, p), "b1": bal(chain, t1, p)})
        except Exception as e:
            out["err"] = str(e)[:80]
        return out

    rows = []
    _t0 = time.time()
    deadline = _t0 + 1500
    futs = [pool.submit(scan, p) for p in pools]
    partial = False
    for i, f in enumerate(as_completed(futs)):
        rows.append(f.result())
        if i and i % 500 == 0:
            log(f"      ..{i}/{len(pools)} pools scanned ({int(time.time()-_t0)}s)")
        if time.time() > deadline:
            partial = True
            break
    pool.shutdown(wait=False, cancel_futures=True)
    if partial:
        res["note"] = (res.get("note", "") + f" partial: {len(rows)}/{len(pools)} pools (timeout)").strip()
    res["pools"] = rows
    for r in rows:
        if "b0" in r:
            add_asset(chain, r["t0"], r["b0"], t, f"pool {r['pool']}")
            add_asset(chain, r["t1"], r["b1"], t, f"pool {r['pool']}")


def h_compound(chain, t, res):
    comptroller = t["comptroller"]
    code = chain.get_code(comptroller)
    if code in ("0x", "0x0", None):
        res["note"] = "comptroller has no code"
        return
    raw = chain.eth_call(comptroller, SEL["getAllMarkets"])
    ws = words(raw)
    if not ws:
        return
    off = dec_uint(ws[0])
    if off // 32 >= len(ws):
        res["note"] = "getAllMarkets decode failed"
        return
    ln = dec_uint(ws[off // 32])
    markets = [dec_addr(ws[off // 32 + 1 + i]) for i in range(ln) if off // 32 + 1 + i < len(ws)]
    res["markets"] = markets
    rows = []
    for m in markets:
        row = {"market": m}
        try:
            u = dec_addr(words(chain.eth_call(m, SEL["underlying"]))[0])
            row["underlying"] = u
            row["cash"] = bal(chain, u, m)
            try:
                row["borrows"] = dec_uint(words(chain.eth_call(m, SEL["totalBorrows"]))[0])
            except Exception:
                row["borrows"] = None
            try:
                row["supply"] = dec_uint(words(chain.eth_call(m, SEL["totalSupply"]))[0])
            except Exception:
                row["supply"] = None
            add_asset(chain, u, row["cash"], t, f"cToken {m}")
        except Exception as e:
            row["err"] = str(e)[:80]
        rows.append(row)
    res["markets_detail"] = rows


def h_sum_tokens(chain, t, res):
    pairs = []
    if "pairs" in t:
        pairs = [tuple(x) for x in t["pairs"]]
    else:
        for o in t["owners"]:
            for tk in t["tokens"]:
                pairs.append((tk, o))
    rows = []
    pool = ThreadPoolExecutor(max_workers=10)
    futs = {pool.submit(bal, chain, tk, o): (tk, o) for tk, o in pairs}
    for f in as_completed(futs):
        tk, o = futs[f]
        try:
            b = f.result()
        except Exception:
            b = 0
        rows.append({"token": tk, "owner": o, "bal": b})
        add_asset(chain, tk, b, t, f"owner {o}")
    pool.shutdown()
    res["balances"] = rows


def h_liquity(chain, t, res):
    tm = t["trove_manager"]
    coll = t["collateral"]
    ap = dec_addr(words(chain.eth_call(tm, SEL["activePool"]))[0])
    dp = dec_addr(words(chain.eth_call(tm, SEL["defaultPool"]))[0])
    res["activePool"] = ap
    res["defaultPool"] = dp
    for pool_addr in [ap, dp, tm]:
        b = bal(chain, coll, pool_addr)
        res.setdefault("coll", []).append({"owner": pool_addr, "bal": b})
        add_asset(chain, coll, b, t, f"liquity pool {pool_addr}")


def h_pala(chain, t, res):
    viewer = t["viewer"]
    sig = ("poolInfos()((address,address,address,string,string,uint8,uint256,uint112,uint112,uint256,uint256)[])")
    try:
        out = subprocess.run(["cast", "call", viewer, sig, "--rpc-url", chain.url],
                             capture_output=True, text=True, timeout=180)
        txt = out.stdout
    except Exception as e:
        res["note"] = f"cast failed: {e}"
        return
    if not txt.strip():
        res["note"] = f"empty cast output: {out.stderr[:120]}"
        return
    addrs = re.findall(r"0x[0-9a-fA-F]{40}", txt)
    triples = [(addrs[i], addrs[i + 1], addrs[i + 2]) for i in range(0, len(addrs) - 2, 3)]
    res["pool_count"] = len(triples)
    rows = []
    pool = ThreadPoolExecutor(max_workers=10)

    def scan(tr):
        p, t0, t1 = tr
        return {"pool": p, "t0": t0, "t1": t1, "b0": bal(chain, t0, p), "b1": bal(chain, t1, p)}

    for f in as_completed([pool.submit(scan, tr) for tr in triples]):
        r = f.result()
        rows.append(r)
        add_asset(chain, r["t0"], r["b0"], t, f"pala pool {r['pool']}")
        add_asset(chain, r["t1"], r["b1"], t, f"pala pool {r['pool']}")
    pool.shutdown()
    res["pools"] = rows


def h_wombat(chain, t, res):
    master = t["master"]
    n = dec_uint(words(chain.eth_call(master, SEL["poolLength"]))[0])
    res["pool_count"] = n
    rows = []
    pool = ThreadPoolExecutor(max_workers=10)

    def scan(i):
        raw = chain.eth_call(master, SEL["poolInfo"] + pad_uint(i))
        ws = words(raw)
        asset = dec_addr(ws[0])
        u = dec_addr(words(chain.eth_call(asset, SEL["underlyingToken"]))[0])
        return {"asset": asset, "underlying": u, "bal": bal(chain, u, asset)}

    for f in as_completed([pool.submit(scan, i) for i in range(min(n, 200))]):
        try:
            r = f.result()
            rows.append(r)
            add_asset(chain, r["underlying"], r["bal"], t, f"wombat asset {r['asset']}")
        except Exception as e:
            rows.append({"err": str(e)[:80]})
    pool.shutdown()
    res["pools"] = rows


def h_splice(chain, t, res):
    factory = t["factory"]
    fb = t.get("from_block", 0)
    logs = get_logs(chain, factory, [SPLICE_TOPIC], fb, chain.block_number())
    pts = []
    for lg in logs:
        topics = lg.get("topics") or []
        if len(topics) >= 3:
            pts.append(dec_addr(topics[2]))
    pts = sorted(set(pts))
    res["market_count"] = len(pts)
    rows = []
    for pt in pts:
        row = {"pt": pt}
        try:
            sy = dec_addr(words(chain.eth_call(pt, SEL["SY"]))[0])
            row["sy"] = sy
            info = words(chain.eth_call(sy, SEL["assetInfo"]))
            asset_type = dec_uint(info[0]) if info else 0
            u = dec_addr(info[1])
            dec_u = dec_uint(info[2]) if len(info) > 2 else 18
            row["uAsset"] = u
            row["sy_balance"] = bal(chain, u, sy)
            row["asset_type"] = asset_type
            claim = None
            try:
                supply = dec_uint(words(chain.eth_call(sy, SEL["totalSupply"]))[0])
                rate = dec_uint(words(chain.eth_call(sy, SEL["exchangeRate"]))[0])
                sy_dec = get_decimals(chain, sy)
                if asset_type == 0:
                    claim = supply * rate // (10 ** 18)
                    if sy_dec != dec_u:
                        claim = claim * (10 ** dec_u) // (10 ** sy_dec)
                else:
                    claim = supply * (10 ** dec_u) // (10 ** sy_dec)
                row["claim_uAsset"] = claim
            except Exception as e:
                row["claim_err"] = str(e)[:60]
            add_asset(chain, u, row["sy_balance"], t, f"SY {sy} direct")
            if claim:
                add_asset(chain, u, claim, t, f"SY {sy} claim(supply x rate)")
        except Exception as e:
            row["err"] = str(e)[:80]
        rows.append(row)
    res["markets"] = rows


def h_cog(chain, t, res):
    factory = t["factory"]
    fb = t.get("from_block", 0)
    logs = get_logs(chain, factory, COG_TOPICS, fb, chain.block_number())
    res["log_count"] = len(logs)
    rows = []
    for lg in logs:
        topics = lg.get("topics") or []
        if len(topics) >= 4:
            asset = dec_addr(topics[1])
            coll = dec_addr(topics[2])
            pair = dec_addr(topics[3])
            ba = bal(chain, asset, pair)
            bc = bal(chain, coll, pair)
            rows.append({"pair": pair, "asset": asset, "collateral": coll, "asset_bal": ba, "coll_bal": bc})
            add_asset(chain, asset, ba, t, f"cog pair {pair}")
            add_asset(chain, coll, bc, t, f"cog pair {pair}")
    res["pairs"] = rows


def h_lp_resolve(chain, t, res):
    rows = []
    for lp in t["lps"]:
        row = {"lp": lp}
        try:
            t0 = dec_addr(words(chain.eth_call(lp, SEL["token0"]))[0])
            t1 = dec_addr(words(chain.eth_call(lp, SEL["token1"]))[0])
            ts = dec_uint(words(chain.eth_call(lp, SEL["totalSupply"]))[0])
            resv = words(chain.eth_call(lp, SEL["getReserves"]))
            r0, r1 = dec_uint(resv[0]), dec_uint(resv[1])
            row.update({"t0": t0, "t1": t1, "totalSupply": ts, "r0": r0, "r1": r1})
            for holder in t["holders"]:
                hb = bal(chain, lp, holder)
                row.setdefault("holders", []).append({"holder": holder, "lp_bal": hb})
                if ts > 0 and hb > 0:
                    add_asset(chain, t0, r0 * hb // ts, t, f"LP {lp} @ {holder}")
                    add_asset(chain, t1, r1 * hb // ts, t, f"LP {lp} @ {holder}")
        except Exception as e:
            row["err"] = str(e)[:100]
        rows.append(row)
    res["lps"] = rows


def h_probe(chain, t, res):
    rows = []
    for addr in t["addresses"]:
        row = {"addr": addr, "code_len": len(chain.get_code(addr) or "0x")}
        for tk in t.get("tokens", []):
            row.setdefault("bals", []).append({"token": tk, "bal": bal(chain, tk, addr)})
            add_asset(chain, tk, row["bals"][-1]["bal"], t, f"probe {addr}")
        rows.append(row)
    res["probes"] = rows


HANDLERS = {
    "uni_v2": h_uni_v2, "uni_v3": h_uni_v3, "compound": h_compound, "sum_tokens": h_sum_tokens,
    "liquity": h_liquity, "pala": h_pala, "wombat": h_wombat, "splice": h_splice,
    "cog": h_cog, "lp_resolve": h_lp_resolve, "probe": h_probe,
}


# ---------------------------------------------------------------- pricing
def price_assets():
    keys = sorted({(a["chain"], a["token"]) for a in ASSETS})
    prices = {}
    chunks = [keys[i:i + 25] for i in range(0, len(keys), 25)]
    for ch in chunks:
        q = ",".join(f"{pc}:{tok}" if tok not in NULLS else f"coingecko:{NATIVE_CG.get(pc, 'ethereum')}"
                     for pc, tok in ch)
        url = "https://coins.llama.fi/prices/current/" + q
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    d = json.loads(r.read().decode())
                for k, v in (d.get("coins") or {}).items():
                    if v.get("price"):
                        prices[k.lower()] = v["price"]
                break
            except Exception as e:
                time.sleep(2 + attempt * 2)
    # retry misses with lowercase
    miss = [k for k in keys if k not in {(pc, tok) for pc, tok in []}]  # noop
    return prices


def asset_usd(a, prices):
    if a["token"] in NULLS:
        k = f"coingecko:{NATIVE_CG.get(a['chain'], 'ethereum')}".lower()
    else:
        k = f"{a['chain']}:{a['token']}".lower()
    p = prices.get(k)
    if p is None and a["token"] not in NULLS:
        p = prices.get(f"{a['chain']}:{a['token']}".lower())
    return (a["amount"] * p) if p else 0.0


# ---------------------------------------------------------------- main
def main():
    t0 = time.time()
    only = os.environ.get("L2B_ONLY", "").strip()
    protos = PLAN["protocols"]
    if only:
        want = {x.strip() for x in only.split(",") if x.strip()}
        protos = [p for p in protos if p["slug"] in want]
    log(f"=== l2-triage-b custody enumeration start {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} protos={len(protos)}")
    results = []
    targets_index = {}
    for pr in protos:
        for t in pr["targets"]:
            tid = f"{pr['slug']}::{t['label']}"
            t["_id"] = tid
            targets_index[tid] = (pr, t)

    for pr in protos:
        pres = {"slug": pr["slug"], "name": pr["name"], "targets": []}
        log(f"--- {pr['slug']}")
        for t in pr["targets"]:
            res = {"label": t["label"], "kind": t["kind"], "chain": t["chain"]}
            chain = CHAINS.get(t["chain"])
            try:
                if chain is None:
                    raise RuntimeError("no rpc configured")
                chain.block_number()
                res["block"] = chain.block
                handler = HANDLERS[t["kind"]]
                handler(chain, t, res)
                res["ok"] = True
            except Exception as e:
                res["ok"] = False
                res["error"] = str(e)[:300]
                log(f"    !! {pr['slug']} / {t['label']}: {str(e)[:200]}")
            pres["targets"].append(res)
            log(f"    {t['label']}: ok={res.get('ok')}")
        results.append(pres)

    log("=== pricing ===")
    prices = price_assets()
    log(f"prices fetched: {len(prices)}")
    # aggregate
    by_target = {}
    for a in ASSETS:
        by_target.setdefault(a["target"], []).append(a)
    summary_rows = []
    for pres in results:
        pr = next(p for p in protos if p["slug"] == pres["slug"])
        total = 0.0
        per_chain = {}
        for t in pres["targets"]:
            tid = f"{pr['slug']}::{t['label']}"
            alist = by_target.get(tid, [])
            usd = sum(asset_usd(a, prices) for a in alist)
            t["usd"] = round(usd, 2)
            t["assets"] = [{"token": a["token"], "amount": a["amount"], "usd": round(asset_usd(a, prices), 2),
                            "src": a["src"]} for a in alist if a["amount"]]
            total += usd
            per_chain[t["chain"]] = per_chain.get(t["chain"], 0) + usd
        pres["total_usd"] = round(total, 2)
        pres["per_chain_usd"] = {k: round(v, 2) for k, v in per_chain.items()}
        for t in pres["targets"]:
            summary_rows.append({
                "protocol": pr["name"], "slug": pr["slug"], "chain": t["chain"],
                "target": t["label"], "kind": t["kind"], "block": t.get("block"),
                "ok": t.get("ok"), "usd": t.get("usd", 0),
                "note": (t.get("note") or t.get("error") or "")[:120],
            })
        log(f"  {pr['slug']}: ${pres['total_usd']:,.0f}")

    with open(os.path.join(OUT, OUT_NAME), "w") as f:
        json.dump({"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                   "prices_count": len(prices), "protocols": results}, f, indent=1)
    with open(os.path.join(OUT, OUT_NAME.replace("results", "summary").replace(".json", ".csv")), "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=["protocol", "slug", "chain", "target", "kind", "block", "ok", "usd", "note"])
        wr.writeheader()
        for r in summary_rows:
            wr.writerow(r)
    log(f"=== done in {int(time.time()-t0)}s; results written to {OUT_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
