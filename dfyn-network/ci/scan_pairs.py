#!/usr/bin/env python3
"""
Dfyn Network Phase-2 full pair integrity scan (read-only).
For every pair on Polygon/Fantom/OKC factories: token0/token1, reserves, LP totalSupply,
actual token balances -> excess (skim-able), deficit (fee-on-transfer/rebasing history).
Prices via DefiLlama coins API. Writes JSON to ci-out/.
No secrets printed. Public endpoints only.
"""
import json, os, re, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "ci-out")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-ci dfyn", "Content-Type": "application/json"}
URL_RE = re.compile(r"https?://\S+")
def redact(s): return URL_RE.sub("<url-redacted>", str(s))[:200]
def env(*names):
    for n in names:
        v = os.environ.get(n)
        if v: return v
    return None

CHAINS = {
    "polygon": {"rpc": [env("POLYGON_RPC_URL"), "https://polygon-bor-rpc.publicnode.com", "https://polygon.drpc.org"],
                "factory": "0xe7fb3e833efe5f9c441105eb65ef8b261266423b", "llama": "polygon"},
    "fantom":  {"rpc": [env("FANTOM_RPC_URL"), "https://fantom.drpc.org", "https://fantom-rpc.publicnode.com", "https://rpcapi.fantom.network"],
                "factory": "0xd9820a17053d6314b20642e465a84bf01a3d64f5", "llama": "fantom"},
    "okc":     {"rpc": ["https://exchainrpc.okex.org"], "factory": "0xe7fb3e833efe5f9c441105eb65ef8b261266423b", "llama": "okexchain"},
}
WORK = {}

def preflight():
    def probe(item):
        ch, url = item
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=12) as r:
                d = json.loads(r.read().decode())
            if "result" in d: return (ch, url, int(d["result"], 16))
        except Exception: return None
    items = [(ch, u) for ch, cfg in CHAINS.items() for u in cfg["rpc"] if u]
    with ThreadPoolExecutor(max_workers=12) as ex:
        for res in ex.map(probe, items):
            if res:
                ch, url, blk = res
                WORK.setdefault(ch, []).append((url, blk))
    for ch, lst in WORK.items():
        lst.sort(key=lambda x: -x[1])
    return {ch: [u for u, _ in lst] for ch, lst in WORK.items()}

def rpc_batch(chain, calls, timeout=90, tries=8):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    urls = [u for u, _ in WORK.get(chain, [])] or [u for u in CHAINS[chain]["rpc"] if u]
    last = None
    for t in range(tries):
        url = urls[t % len(urls)]
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item["result"] if "result" in item else {"error": item.get("error")}
                return out
            last = redact(d)
        except Exception as e:
            last = redact(e)
            time.sleep(1.5 * (t + 1))
    raise RuntimeError(f"batch fail {chain}: {last}")

def call(chain, to, data):
    r = rpc_batch(chain, [("eth_call", [{"to": to, "data": data}, "latest"])])
    v = r[0]
    return v if isinstance(v, str) else None
def dec_addr(h): return "0x" + h[-40:] if isinstance(h, str) and len(h) >= 42 else None
def dec_int(h):
    try: return int(h, 16)
    except: return None
def dec_word(h):
    """First 32-byte word of an eth_call return (extra words ignored)."""
    try: return int(h[2:66], 16) if isinstance(h, str) and len(h) >= 66 else None
    except: return None
def pad(a): return a.lower().replace("0x", "").rjust(64, "0")

SEL = {"allPairsLength": "0x574f2ba3", "allPairs": "0x1e3dd18b", "token0": "0x0dfe1681",
       "token1": "0xd21220a7", "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd",
       "balanceOf": "0x70a08231", "decimals": "0x313ce567", "symbol": "0x95d89b41"}

def llama_prices(llama_chain, addrs, tries=4):
    out = {}
    addrs = [a.lower() for a in addrs if a and a.startswith("0x")]
    uniq = list(dict.fromkeys(addrs))
    for i in range(0, len(uniq), 60):
        chunk = uniq[i:i+60]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"{llama_chain}:{a}" for a in chunk)
        for t in range(tries):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": UA["User-Agent"]})
                with urllib.request.urlopen(req, timeout=30) as r:
                    d = json.loads(r.read().decode())
                for k, v in (d.get("coins") or {}).items():
                    a = k.split(":")[-1].lower()
                    if v.get("price") is not None and float(v["price"]) < 1e7:
                        out[a] = {"price": float(v["price"]), "decimals": v.get("decimals")}
                break
            except Exception:
                time.sleep(2.0 * (t + 1))
    return out

def dec_str(h):
    try:
        b = bytes.fromhex(h[2:]); ln = int.from_bytes(b[32:64], "big"); return b[64:64+ln].decode("utf-8", "replace")[:32]
    except Exception: return None

def scan_chain(chain):
    cfg = CHAINS[chain]
    fac = cfg["factory"]
    blk_res = rpc_batch(chain, [("eth_blockNumber", [])])
    start_block = int(blk_res[0], 16) if isinstance(blk_res[0], str) else None
    n = dec_int(call(chain, fac, SEL["allPairsLength"]))
    print(f"[{chain}] allPairsLength={n}", flush=True)
    pairs = []
    for i in range(0, n, 50):
        idxs = list(range(i, min(i+50, n)))
        res = rpc_batch(chain, [("eth_call", [{"to": fac, "data": SEL["allPairs"] + hex(j)[2:].rjust(64, "0")}, "latest"]) for j in idxs])
        for r in res:
            pairs.append(dec_addr(r) if isinstance(r, str) else None)
    pairs = [p for p in pairs if p]
    print(f"[{chain}] pairs fetched={len(pairs)}", flush=True)

    rows = []
    CH = 25
    for i in range(0, len(pairs), CH):
        chunk = pairs[i:i+CH]
        calls = []
        for p in chunk:
            calls += [("eth_call", [{"to": p, "data": SEL["token0"]}, "latest"]),
                      ("eth_call", [{"to": p, "data": SEL["token1"]}, "latest"]),
                      ("eth_call", [{"to": p, "data": SEL["getReserves"]}, "latest"]),
                      ("eth_call", [{"to": p, "data": SEL["totalSupply"]}, "latest"])]
        r = rpc_batch(chain, calls)
        meta = []
        for j, p in enumerate(chunk):
            t0 = dec_addr(r[j*4]); t1 = dec_addr(r[j*4+1]); rr = r[j*4+2]; ts = dec_int(r[j*4+3]) if isinstance(r[j*4+3], str) else None
            r0 = r1 = None
            if isinstance(rr, str) and len(rr) >= 130:
                r0 = int(rr[2:66], 16); r1 = int(rr[66:130], 16)
            meta.append([p, t0, t1, r0, r1, ts])
        calls = []
        for p, t0, t1, r0, r1, ts in meta:
            if t0: calls.append(("eth_call", [{"to": t0, "data": SEL["balanceOf"] + pad(p)}, "latest"]))
            else: calls.append(("eth_call", [{"to": "0x0000000000000000000000000000000000000000", "data": "0x"}, "latest"]))
            if t1: calls.append(("eth_call", [{"to": t1, "data": SEL["balanceOf"] + pad(p)}, "latest"]))
            else: calls.append(("eth_call", [{"to": "0x0000000000000000000000000000000000000000", "data": "0x"}, "latest"]))
        b = rpc_batch(chain, calls)
        for j, (p, t0, t1, r0, r1, ts) in enumerate(meta):
            b0 = dec_word(b[2*j])
            b1 = dec_word(b[2*j+1])
            rows.append({"pair": p, "t0": t0, "t1": t1, "r0": r0, "r1": r1, "ts": ts, "b0": b0, "b1": b1})
        print(f"[{chain}] {min(i+CH, len(pairs))}/{len(pairs)}", flush=True)

    # unique tokens + prices
    toks = set()
    for row in rows:
        for t in (row["t0"], row["t1"]):
            if t: toks.add(t)
    prices = llama_prices(cfg["llama"], sorted(toks))
    # decimals for ALL tokens (on-chain), symbols for unpriced
    all_toks = sorted(toks)
    decs = {}
    syms = {}
    for i in range(0, len(all_toks), 30):
        ch = all_toks[i:i+30]
        calls = []
        for t in ch:
            calls += [("eth_call", [{"to": t, "data": SEL["decimals"]}, "latest"]),
                      ("eth_call", [{"to": t, "data": SEL["symbol"]}, "latest"])]
        r = rpc_batch(chain, calls)
        for j, t in enumerate(ch):
            decs[t] = dec_int(r[2*j]) if isinstance(r[2*j], str) else None
            syms[t] = dec_str(r[2*j+1]) if isinstance(r[2*j+1], str) else None
    unpriced = [t for t in all_toks if t not in prices]

    # enrich
    for row in rows:
        t0 = (row["t0"] or "").lower(); t1 = (row["t1"] or "").lower()
        d0 = decs.get(row["t0"]) if decs.get(row["t0"]) is not None else (prices.get(t0, {}).get("decimals") or 18)
        d1 = decs.get(row["t1"]) if decs.get(row["t1"]) is not None else (prices.get(t1, {}).get("decimals") or 18)
        p0 = prices.get(t0, {}).get("price", 0.0)
        p1 = prices.get(t1, {}).get("price", 0.0)
        row["d0"] = d0; row["d1"] = d1; row["p0"] = p0; row["p1"] = p1
        r0 = row["r0"] or 0; r1 = row["r1"] or 0
        a0 = r0 / (10 ** d0) if d0 is not None else 0.0
        a1 = r1 / (10 ** d1) if d1 is not None else 0.0
        row["reserves_usd"] = a0 * p0 + a1 * p1
        ex0 = (row["b0"] - r0) if row["b0"] is not None else None
        ex1 = (row["b1"] - r1) if row["b1"] is not None else None
        # fake-balance heuristic: absurd magnitude vs reserve and > 2^160
        row["fake0"] = bool(ex0 and ex0 > 0 and row["b0"] > 2**160 and (r0 == 0 or row["b0"] > 10**6 * max(r0, 1)))
        row["fake1"] = bool(ex1 and ex1 > 0 and row["b1"] > 2**160 and (r1 == 0 or row["b1"] > 10**6 * max(r1, 1)))
        row["ex0"] = ex0; row["ex1"] = ex1
        ex0_usd = (ex0 or 0) / (10 ** d0) * p0 if d0 is not None else 0.0
        ex1_usd = (ex1 or 0) / (10 ** d1) * p1 if d1 is not None else 0.0
        row["excess_usd"] = (0 if row["fake0"] else ex0_usd) + (0 if row["fake1"] else ex1_usd)
        row["fake_excess_usd"] = (ex0_usd if row["fake0"] else 0) + (ex1_usd if row["fake1"] else 0)
        row["deficit0"] = bool(ex0 is not None and ex0 < 0)
        row["deficit1"] = bool(ex1 is not None and ex1 < 0)
    return {"chain": chain, "block": start_block, "n_pairs": len(rows), "rows": rows,
            "prices": prices, "symbols": {t: {"symbol": syms.get(t), "decimals": decs.get(t)} for t in all_toks}}

def main():
    pf = preflight()
    print("preflight:", {k: len(v) for k, v in pf.items()}, flush=True)
    summary = {"chains": {}, "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    for chain in CHAINS:
        if chain not in WORK:
            print(f"[{chain}] no working RPC", flush=True)
            continue
        try:
            res = scan_chain(chain)
        except Exception as e:
            print(f"[{chain}] FAILED: {redact(e)}", flush=True)
            summary["chains"][chain] = {"error": redact(e)}
            continue
        rows = res["rows"]
        json.dump(res, open(os.path.join(OUT, f"pairs-{chain}.json"), "w"))
        live = [r for r in rows if (r["r0"] or 0) > 0 or (r["r1"] or 0) > 0]
        excess = sorted([r for r in rows if (r["excess_usd"] or 0) > 0.01], key=lambda x: -x["excess_usd"])
        fake = sorted([r for r in rows if (r["fake_excess_usd"] or 0) > 0.01], key=lambda x: -x["fake_excess_usd"])
        deficits = sorted([r for r in rows if r["deficit0"] or r["deficit1"]], key=lambda x: -(x["reserves_usd"] or 0))
        top = sorted(rows, key=lambda x: -(x["reserves_usd"] or 0))[:40]
        totals = {
            "block": res["block"],
            "n_pairs": len(rows), "n_live_reserves": len(live),
            "reserves_usd_total": round(sum(r["reserves_usd"] for r in rows), 2),
            "excess_usd_total_real": round(sum(r["excess_usd"] for r in rows), 4),
            "excess_usd_total_fake": round(sum(r["fake_excess_usd"] for r in rows), 4),
            "n_excess_pairs": len(excess), "n_fake_excess_pairs": len(fake), "n_deficit_pairs": len(deficits),
            "top_pools": [{"pair": r["pair"], "usd": round(r["reserves_usd"], 2), "t0": r["t0"], "t1": r["t1"],
                           "r0": r["r0"], "r1": r["r1"], "ts": r["ts"]} for r in top],
            "top_excess": [{"pair": r["pair"], "usd": round(r["excess_usd"], 4), "ex0": r["ex0"], "ex1": r["ex1"],
                            "t0": r["t0"], "t1": r["t1"]} for r in excess[:25]],
            "top_fake_excess": [{"pair": r["pair"], "usd": round(r["fake_excess_usd"], 4), "ex0": r["ex0"], "ex1": r["ex1"],
                                 "t0": r["t0"], "t1": r["t1"]} for r in fake[:25]],
            "top_deficits": [{"pair": r["pair"], "usd": round(r["reserves_usd"], 2), "ex0": r["ex0"], "ex1": r["ex1"],
                              "t0": r["t0"], "t1": r["t1"]} for r in deficits[:25]],
            "unpriced": {t: v for t, v in res["symbols"].items() if t not in res["prices"]},
        }
        summary["chains"][chain] = totals
        print(f"[{chain}] SUMMARY: pairs={totals['n_pairs']} live={totals['n_live_reserves']} "
              f"reserves=${totals['reserves_usd_total']} real_excess=${totals['excess_usd_total_real']} "
              f"fake_excess=${totals['excess_usd_total_fake']} deficits={totals['n_deficit_pairs']}", flush=True)
        for r in top[:10]:
            print(f"  TOP pool {r['pair']} ${r['reserves_usd']:.2f} r0={r['r0']} r1={r['r1']} ts={r['ts']}", flush=True)
        for r in excess[:10]:
            print(f"  EXCESS {r['pair']} ${r['excess_usd']:.4f} ex0={r['ex0']} ex1={r['ex1']}", flush=True)
        for r in deficits[:10]:
            print(f"  DEFICIT {r['pair']} ${r['reserves_usd']:.2f} ex0={r['ex0']} ex1={r['ex1']} t0={r['t0']} t1={r['t1']}", flush=True)
    json.dump(summary, open(os.path.join(OUT, "scan-summary.json"), "w"), indent=1)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
