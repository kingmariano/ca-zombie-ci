#!/usr/bin/env python3
"""BaseSwap V2 (Base) full pair enumeration + live-value/excess scan. v2 (fast).

Read-only. Runs against BASE_RPC_URL (CI secret; never printed) plus keyless public
fallbacks. Writes JSON evidence to ci-out/ (or --out dir).

v2 changes: threaded batch fetching with endpoint rotation, codehash sampling
(instead of fetching all 8,290 pair bytecodes), no kLast fetch.
"""
import json, os, sys, time, urllib.request, urllib.error, random, hashlib
from concurrent.futures import ThreadPoolExecutor

FACTORY = "0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB"
MASTERCHEF = "0x2B0A43DCcBD7d42c18F6A83F86D1a19fA58d541A"
BSWAP = "0x78a087d713Be963Bf307b18F2Ff8122EF9A63ae9"
FEE_TO = "0x463112327576814f80DA8D3632f7bad23c853A29"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ci-out")
if "--out" in sys.argv:
    OUT = sys.argv[sys.argv.index("--out") + 1]
LIMIT = None
if "--limit" in sys.argv:
    LIMIT = int(sys.argv[sys.argv.index("--limit") + 1])
CHUNK = 50
if "--chunk" in sys.argv:
    CHUNK = int(sys.argv[sys.argv.index("--chunk") + 1])
WORKERS = 6
if "--workers" in sys.argv:
    WORKERS = int(sys.argv[sys.argv.index("--workers") + 1])
os.makedirs(OUT, exist_ok=True)

PUBLIC = ["https://base-rpc.publicnode.com", "https://base.drpc.org",
          "https://1rpc.io/base", "https://mainnet.base.org",
          "https://base.meowrpc.com"]
RPC = os.environ.get("BASE_RPC_URL") or ""
if "--rpc" in sys.argv:
    RPC = sys.argv[sys.argv.index("--rpc") + 1]
ENDPOINTS = ([RPC] if RPC else []) + [u for u in PUBLIC if u != RPC]
SINGLE = "--single" in sys.argv
if SINGLE and RPC:
    ENDPOINTS = [RPC]

def _probe(url):
    # timed 25-call batch; return (ok, seconds)
    payload = [{"jsonrpc": "2.0", "id": i + 1, "method": "eth_blockNumber", "params": []} for i in range(25)]
    t = time.time()
    try:
        res = _post(url, payload)
        ok = sum(1 for x in res if "result" in x) == 25
        return (ok, time.time() - t)
    except Exception:
        return (False, 99.0)

def probe_endpoints():
    global ENDPOINTS
    good = []
    for u in ENDPOINTS:
        ok, dt = _probe(u)
        if ok:
            good.append((dt, u))
    if good:
        good.sort()
        # keep the fastest endpoint, plus the second if it is close (<2.5x slower)
        ENDPOINTS = [good[0][1]]
        if len(good) > 1 and good[1][0] < good[0][0] * 2.5:
            ENDPOINTS.append(good[1][1])
    return [(round(dt, 2), u) for dt, u in good]

SEL = {
    "allPairs": "0x1e3dd18b", "allPairsLength": "0x574f2ba3",
    "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd",
    "token0": "0x0dfe1681", "token1": "0xd21220a7",
    "balanceOf": "0x70a08231", "decimals": "0x313ce567",
    "symbol": "0x95d89b41", "name": "0x06fdde03",
    "kLast": "0x7464fc3d", "factory": "0xc45a0155",
    "poolInfo": "0x1526fe27", "poolLength": "0x081e3eda",
    "feeTo": "0x017e7e58", "totalAllocPoint": "0x17caf6f1",
    "bswapPerSec": "0xbaffebb6", "owner": "0x8da5cb5b",
}

def redact(s):
    for u in ENDPOINTS:
        s = s.replace(u, "<rpc>")
    return s

_ep_lock = None
try:
    import threading
    _ep_lock = threading.Lock()
except Exception:
    pass
_ep_counter = [0]

def _next_ep():
    if _ep_lock:
        with _ep_lock:
            i = _ep_counter[0]; _ep_counter[0] += 1
    else:
        i = _ep_counter[0]; _ep_counter[0] += 1
    return ENDPOINTS[i % len(ENDPOINTS)]

_id_lock = None
try:
    import threading as _th
    _id_lock = _th.Lock()
except Exception:
    pass
_id = [0]

def _post(url, payload):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={
        "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 research"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())

def rpc_chunk(part):
    """One chunk of (method, params) -> list of results; rotates endpoints, halves on failure."""
    with _id_lock:
        base_id = _id[0]
        _id[0] += len(part)
    payload = []
    for k, (m, p) in enumerate(part):
        payload.append({"jsonrpc": "2.0", "id": base_id + k + 1, "method": m, "params": p})
    last = None
    for attempt in range(5):
        url = _next_ep()
        try:
            res = _post(url, payload)
            if isinstance(res, dict) and res.get("error"):
                raise RuntimeError(str(res["error"])[:150])
            byid = {x["id"]: x for x in res}
            out = []
            for x in payload:
                item = byid.get(x["id"], {})
                if "error" in item:
                    err = str(item.get("error"))
                    # deterministic execution reverts are not retryable
                    out.append("__REVERT__" if ("revert" in err.lower() or "execution" in err.lower()) else None)
                else:
                    out.append(item.get("result"))
            return out
        except Exception as e:
            last = e
            time.sleep(0.3 * (attempt + 1) + random.random() * 0.3)
    if len(part) > 10:
        mid = len(part) // 2
        return rpc_chunk(part[:mid]) + rpc_chunk(part[mid:])
    print("[warn] chunk failed after retries:", redact(str(last))[:160], flush=True)
    return [None] * len(part)

def rpc_batch(calls, chunk=None, workers=None):
    chunk = chunk or CHUNK
    workers = workers or WORKERS
    chunks = [calls[i:i + chunk] for i in range(0, len(calls), chunk)]
    out = []
    with ThreadPoolExecutor(max_workers=workers) as ex:
        for res in ex.map(rpc_chunk, chunks):
            out.extend(res)
    return out

def fetch_with_retry(calls, chunk=None, rounds=4, label=""):
    """rpc_batch + retry of None entries in shrinking batches. Returns list aligned with calls."""
    results = rpc_batch(calls, chunk=chunk)
    for rnd in range(rounds):
        missing = [i for i, r in enumerate(results) if r is None]
        if not missing:
            break
        sub_calls = [calls[i] for i in missing]
        sub_res = rpc_batch(sub_calls, chunk=max(5, (chunk or CHUNK) // 5),
                            workers=max(2, WORKERS // 2))
        for i, r in zip(missing, sub_res):
            if r is not None:
                results[i] = r
        print(f"[retry {label}] round {rnd+1}: still missing "
              f"{sum(1 for r in results if r is None)}/{len(results)}", flush=True)
        time.sleep(0.5)
    return results

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def enc_uint(n):
    return hex(n)[2:].rjust(64, "0")

def call(addr, sel, arg=None):
    return ("eth_call", [{"to": addr, "data": sel + (arg or "")}, "latest"])

def dec_uint(hexstr):
    if not hexstr or hexstr == "0x" or hexstr == "__REVERT__":
        return None
    return int(hexstr, 16)

def dec_addr(hexstr):
    if not hexstr or len(hexstr) < 42:
        return None
    return "0x" + hexstr[-40:]

def dec_str(hexstr):
    if not hexstr or hexstr == "0x" or hexstr == "__REVERT__":
        return None
    try:
        b = bytes.fromhex(hexstr[2:])
    except Exception:
        return None
    if len(b) >= 64:
        try:
            off = int.from_bytes(b[0:32], "big")
            ln = int.from_bytes(b[off:off + 32], "big")
            raw = b[off + 32:off + 32 + ln]
            return raw.decode("utf-8", "replace").replace("\x00", "").strip()
        except Exception:
            pass
    try:
        return b.rstrip(b"\x00").decode("utf-8", "replace").strip()
    except Exception:
        return None

def main():
    t0 = time.time()
    log = []
    def L(*a):
        s = " ".join(str(x) for x in a)
        log.append(s)
        print(s, flush=True)

    probe_endpoints()
    L("endpoints_available", len(ENDPOINTS))  # count only; never log URLs
    bn = dec_uint(rpc_batch([("eth_blockNumber", [])], chunk=1, workers=1)[0])
    L("block", bn)
    n = dec_uint(rpc_batch([call(FACTORY, SEL["allPairsLength"])], chunk=1, workers=1)[0])
    L("allPairsLength", n)
    if LIMIT:
        n = min(n, LIMIT)
    res = fetch_with_retry([call(FACTORY, SEL["allPairs"], enc_uint(i)) for i in range(n)],
                           label="allPairs")
    pairs = []
    missing_idx = []
    for i, r in enumerate(res):
        a = dec_addr(r)
        if a:
            pairs.append(a.lower())
        else:
            missing_idx.append(i)
    if missing_idx:
        L("WARNING missing pair indices:", len(missing_idx), missing_idx[:20])
    L("pairs fetched", len(pairs), round(time.time() - t0, 1))

    # token0/token1/reserves/supply per pair (4 calls)
    calls = []
    for p in pairs:
        calls += [call(p, SEL["token0"]), call(p, SEL["token1"]),
                  call(p, SEL["getReserves"]), call(p, SEL["totalSupply"])]
    r = fetch_with_retry(calls, label="state")
    base = []
    tokens = set()
    for i, p in enumerate(pairs):
        t0_ = dec_addr(r[4 * i]); t1_ = dec_addr(r[4 * i + 1])
        rv = r[4 * i + 2]; sup = dec_uint(r[4 * i + 3])
        res0 = res1 = None
        if rv and len(rv) >= 194:
            res0 = int(rv[2:66], 16); res1 = int(rv[66:130], 16)
        base.append({"pair": p, "token0": t0_, "token1": t1_, "reserve0": res0,
                     "reserve1": res1, "totalSupply": sup})
        if t0_: tokens.add(t0_.lower())
        if t1_: tokens.add(t1_.lower())
    L("pair state fetched", len(base), round(time.time() - t0, 1))

    # balances per pair token
    calls = []
    idx = []
    for i, b in enumerate(base):
        if b["token0"]:
            calls.append(call(b["token0"], SEL["balanceOf"], enc_addr(b["pair"]))); idx.append((i, 0))
        if b["token1"]:
            calls.append(call(b["token1"], SEL["balanceOf"], enc_addr(b["pair"]))); idx.append((i, 1))
    r = fetch_with_retry(calls, label="balances")
    for (i, side), v in zip(idx, r):
        base[i]["balance0" if side == 0 else "balance1"] = dec_uint(v)
    L("balances fetched", round(time.time() - t0, 1))

    # feeTo (FactoryManager) LP holdings per pair -> exact protocol-fee value
    r = fetch_with_retry([call(b["pair"], SEL["balanceOf"], enc_addr(FEE_TO)) for b in base],
                         label="feeTo")
    for b, v in zip(base, r):
        b["feeTo_lp"] = dec_uint(v)
    L("feeTo LP fetched", round(time.time() - t0, 1))

    # codehash sampling (every 50th pair + first/last 20)
    sample = sorted(set(list(range(0, min(20, len(pairs)))) +
                        list(range(max(0, len(pairs) - 20), len(pairs))) +
                        list(range(0, len(pairs), 50))))
    r = rpc_batch([("eth_getCode", [pairs[i], "latest"]) for i in sample], chunk=20)
    ch = {}
    for i, code in zip(sample, r):
        if code:
            h = hashlib.sha256(bytes.fromhex(code[2:])).hexdigest()[:16]
            ch.setdefault(h, []).append(pairs[i])
    code_hashes = {h: len(v) for h, v in ch.items()}
    L("code sample", len(sample), "hashes", json.dumps(code_hashes), round(time.time() - t0, 1))

    # token metadata
    tok_list = sorted(tokens)
    calls = []
    for t in tok_list:
        calls += [call(t, SEL["symbol"]), call(t, SEL["decimals"])]
    r = fetch_with_retry(calls, label="metadata")
    meta = {}
    for i, t in enumerate(tok_list):
        sym = dec_str(r[2 * i]); dec = dec_uint(r[2 * i + 1])
        meta[t] = {"symbol": sym, "decimals": dec}
    L("token metadata", len(tok_list), round(time.time() - t0, 1))

    # prices from DefiLlama
    prices = {}
    CH = 80
    for i in range(0, len(tok_list), CH):
        chunk = tok_list[i:i + CH]
        q = ",".join("base:" + t for t in chunk)
        url = "https://coins.llama.fi/prices/current/" + q
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 research"})
                with urllib.request.urlopen(req, timeout=40) as rr:
                    d = json.loads(rr.read().decode())
                for k, v in d.get("coins", {}).items():
                    addr = k.split(":")[1].lower()
                    prices[addr] = v.get("price")
                    if meta.get(addr, {}).get("decimals") is None and v.get("decimals") is not None:
                        meta.setdefault(addr, {})["decimals"] = v.get("decimals")
                        meta[addr]["decimals_source"] = "llama"
                break
            except Exception:
                time.sleep(1 + attempt * 2)
        time.sleep(0.2)
    L("llama prices", len(prices), round(time.time() - t0, 1))

    # implied prices from pairs with exactly one priced side (sane only)
    implied = {}
    for b in base:
        t0_, t1_ = b["token0"], b["token1"]
        if not t0_ or not t1_ or not b["reserve0"] or not b["reserve1"]:
            continue
        m0 = meta.get(t0_.lower(), {}); m1 = meta.get(t1_.lower(), {})
        # require known decimals on both sides (avoid 1e12-scale artifacts)
        if m0.get("decimals") is None or m1.get("decimals") is None:
            continue
        d0 = m0["decimals"]; d1 = m1["decimals"]
        h0 = b["reserve0"] / 10 ** d0
        h1 = b["reserve1"] / 10 ** d1
        p0 = prices.get(t0_.lower()); p1 = prices.get(t1_.lower())
        if p0 and not p1 and h1 > 0:
            val0 = h0 * p0
            if val0 < 10:  # dust-derived prices are noise
                continue
            cand = val0 / h1
            if 1e-18 <= cand <= 1e6:
                if t1_.lower() not in implied or implied[t1_.lower()][0] < val0:
                    implied[t1_.lower()] = (val0, cand)
        if p1 and not p0 and h0 > 0:
            val1 = h1 * p1
            if val1 < 10:
                continue
            cand = val1 / h0
            if 1e-18 <= cand <= 1e6:
                if t0_.lower() not in implied or implied[t0_.lower()][0] < val1:
                    implied[t0_.lower()] = (val1, cand)
    for t, (val, pr) in implied.items():
        if t not in prices:
            prices[t] = pr
            meta.setdefault(t, {})["price_source"] = "implied"
    L("implied prices", len(implied), round(time.time() - t0, 1))

    # value pairs + excess
    def tprice(t):
        return prices.get((t or "").lower())

    tot_hard = 0.0; tot_inferred = 0.0
    excess_rows = []
    broken = []
    out_pairs = []
    for b in base:
        t0_, t1_ = b["token0"], b["token1"]
        if not t0_ or not t1_:
            continue
        d0 = (meta.get(t0_.lower(), {}).get("decimals") or 18)
        d1 = (meta.get(t1_.lower(), {}).get("decimals") or 18)
        p0 = tprice(t0_); p1 = tprice(t1_)
        h0 = (b["reserve0"] or 0) / 10 ** d0
        h1 = (b["reserve1"] or 0) / 10 ** d1
        v0 = h0 * p0 if p0 else None
        v1 = h1 * p1 if p1 else None
        tvl = (v0 or 0) + (v1 or 0)
        both_hard = bool(p0 and p1 and meta.get(t0_.lower(), {}).get("price_source") != "implied"
                         and meta.get(t1_.lower(), {}).get("price_source") != "implied")
        if both_hard:
            tot_hard += tvl
        tot_inferred += tvl
        e0 = (b["balance0"] - b["reserve0"]) if (b.get("balance0") is not None and b["reserve0"] is not None) else None
        e1 = (b["balance1"] - b["reserve1"]) if (b.get("balance1") is not None and b["reserve1"] is not None) else None
        def val_excess(e, p, d):
            return (e / 10 ** d) * p if (e and e > 0 and p) else 0.0
        ev0 = val_excess(e0, p0, d0); ev1 = val_excess(e1, p1, d1)
        fee_lp = b.get("feeTo_lp")
        fee_usd = (tvl * fee_lp / b["totalSupply"]) if (fee_lp and b["totalSupply"]) else 0.0
        row = {
            "pair": b["pair"], "token0": t0_, "token1": t1_,
            "sym0": meta.get(t0_.lower(), {}).get("symbol"),
            "sym1": meta.get(t1_.lower(), {}).get("symbol"),
            "dec0": d0, "dec1": d1,
            "reserve0": b["reserve0"], "reserve1": b["reserve1"],
            "balance0": b.get("balance0"), "balance1": b.get("balance1"),
            "totalSupply": b["totalSupply"], "feeTo_lp": fee_lp,
            "feeTo_usd": round(fee_usd, 4),
            "excess0": e0, "excess1": e1,
            "excess_usd": round(ev0 + ev1, 4),
            "price0": p0, "price1": p1,
            "tvl_usd": round(tvl, 2), "priced_both": both_hard,
        }
        out_pairs.append(row)
        if (e0 is not None and e0 > 0) or (e1 is not None and e1 > 0):
            excess_rows.append(row)
        if (e0 is not None and e0 < 0) or (e1 is not None and e1 < 0):
            broken.append(row)
    excess_rows.sort(key=lambda x: -x["excess_usd"])
    out_pairs.sort(key=lambda x: -x["tvl_usd"])

    # masterchef pools
    mc = {"address": MASTERCHEF, "block": bn, "pools": []}
    pl = dec_uint(rpc_batch([call(MASTERCHEF, SEL["poolLength"])], chunk=1, workers=1)[0])
    if pl:
        calls = [call(MASTERCHEF, SEL["poolInfo"], enc_uint(i)) for i in range(pl)]
        r = rpc_batch(calls, chunk=20)
        for i, rr in enumerate(r):
            if not rr or len(rr) < 320:
                continue
            lp = dec_addr(rr[2:66]); alloc = int(rr[66:130], 16)
            lrt = int(rr[130:194], 16); aps = int(rr[194:258], 16); td = int(rr[258:322], 16)
            mc["pools"].append({"pid": i, "lpToken": lp, "allocPoint": alloc,
                                "lastRewardTime": lrt, "accPerShare": aps, "totalDeposit": td})
        calls = [call(p["lpToken"], SEL["balanceOf"], enc_addr(MASTERCHEF)) for p in mc["pools"]]
        r = rpc_batch(calls, chunk=20)
        for p, v in zip(mc["pools"], r):
            p["mcBalance"] = dec_uint(v)
    mc["bswapBalance"] = dec_uint(rpc_batch([call(BSWAP, SEL["balanceOf"], enc_addr(MASTERCHEF))], chunk=1, workers=1)[0])
    mc["bswapPerSec"] = dec_uint(rpc_batch([call(MASTERCHEF, SEL["bswapPerSec"])], chunk=1, workers=1)[0])
    mc["totalAllocPoint"] = dec_uint(rpc_batch([call(MASTERCHEF, SEL["totalAllocPoint"])], chunk=1, workers=1)[0])
    mc["owner"] = dec_addr(rpc_batch([call(MASTERCHEF, SEL["owner"])], chunk=1, workers=1)[0])
    mc["feeTo"] = dec_addr(rpc_batch([call(FACTORY, SEL["feeTo"])], chunk=1, workers=1)[0])

    tot_excess = sum(x["excess_usd"] for x in excess_rows)
    tot_fee = sum(x.get("feeTo_usd") or 0 for x in out_pairs)
    coverage = {
        "pairs_total": n,
        "pairs_with_tokens": len(base),
        "pairs_with_reserves": len([b for b in base if b["reserve0"] is not None and b["reserve1"] is not None]),
        "pairs_with_balances": len([b for b in base if b.get("balance0") is not None and b.get("balance1") is not None]),
        "pairs_with_supply": len([b for b in base if b["totalSupply"] is not None]),
        "pairs_with_feeTo": len([b for b in base if b.get("feeTo_lp") is not None]),
        "tokens_total": len(tokens),
        "tokens_with_metadata": len([t for t in tokens if meta.get(t, {}).get("decimals") is not None]),
    }
    summary = {
        "factory": FACTORY, "block": bn, "pair_count": len(base),
        "coverage": coverage,
        "code_sample_size": len(sample), "code_hashes": code_hashes,
        "tvl_usd_hard_priced": round(tot_hard, 2),
        "tvl_usd_with_implied": round(tot_inferred, 2),
        "feeTo_lp_usd_all_pairs": round(tot_fee, 2),
        "pairs_with_excess": len(excess_rows),
        "skim_excess_usd": round(tot_excess, 2),
        "pairs_balance_lt_reserve": len(broken),
        "zero_supply_pairs": len([x for x in out_pairs if x["totalSupply"] == 0]),
        "priced_tokens": len([t for t in tokens if t in prices]),
        "total_tokens": len(tokens),
        "elapsed_s": round(time.time() - t0, 1),
        "rpc": "<redacted>",
    }
    json.dump(summary, open(os.path.join(OUT, "scan_summary.json"), "w"), indent=1)
    json.dump(out_pairs, open(os.path.join(OUT, "pairs.json"), "w"))
    json.dump(excess_rows[:200], open(os.path.join(OUT, "excess_pairs.json"), "w"), indent=1)
    json.dump(out_pairs[:100], open(os.path.join(OUT, "top_pairs.json"), "w"), indent=1)
    json.dump({"tokens": meta, "prices": prices}, open(os.path.join(OUT, "tokens.json"), "w"))
    json.dump(mc, open(os.path.join(OUT, "masterchef.json"), "w"), indent=1)
    L("SUMMARY", json.dumps(summary))
    L("done", round(time.time() - t0, 1), "s")
    open(os.path.join(OUT, "scan_log.txt"), "w").write("\n".join(log) + "\n")

if __name__ == "__main__":
    main()
