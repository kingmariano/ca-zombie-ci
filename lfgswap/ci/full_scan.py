#!/usr/bin/env python3
"""
LFGSwap EthereumPoW (ETHW, chainid 10001) — full live-state scan + arbitrage cycle search.

READ-ONLY. Public keyless RPC only (NEVER put a keyed URL in this repo).
Outputs (written to <folder>/ci-out/):
  pairs_fresh.json     — every pair with fresh reserves/balances/totalSupply/kLast at scan block
  excess.json          — pairs with balance > reserve (skim-able) or one-sided reserves
  fee_mint.json        — per-pair protocol-fee LP mintable estimate (kLast growth)
  arb_cycles.json      — best executable cycles (2 and 3 hops) with optimal input size, ranked by USD
  scan_summary.json    — aggregates (totals per token, block, counts)
  pairs_summary.csv    — flat table for eyeballing
"""
import json, os, sys, time, urllib.request, math
from collections import defaultdict

RPC = os.environ.get("ETHW_RPC_URL", "https://mainnet.ethereumpow.org")
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ci-out")
os.makedirs(OUT, exist_ok=True)
FACTORY = "0xf66cef53c518659bFA0A9a4Aa07445AF08bf9B3a"
WETHW = "0x7bf88d2c0e32de92cdaf2d43ccdc23e8edfd5990".lower()
USDT = "0x2ad7868ca212135c6119fd7ad1ce51cfc5702892".lower()
USDC = "0x25de68ef588cb0c2c8f3537861e828ae699cd0db".lower()
BUSD = "0xf61eb8999f2f222f425d41da4c2ff4b6d8320c87".lower()
WBTC = "0x4bbd68d8b1f25ae7b460e3347c637fe9e7338e0c".lower()
FEE = 0.997

def log(*a):
    print(*a, flush=True)

# ---------------------------------------------------------------- rpc
class Rpc:
    def __init__(self, url):
        self.url = url
        self.id = 0
    def batch(self, calls, tries=6):
        """calls: list of (method, params). Returns list of results (None on execution revert)."""
        for a in range(tries):
            try:
                reqs = []
                for m, p in calls:
                    self.id += 1
                    reqs.append({"jsonrpc": "2.0", "id": self.id, "method": m, "params": p})
                req = urllib.request.Request(self.url, data=json.dumps(reqs).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                r = json.loads(urllib.request.urlopen(req, timeout=60).read())
                if isinstance(r, dict):
                    r = [r]
                byid = {x["id"]: x for x in r}
                out = []
                for req_j in reqs:
                    x = byid.get(req_j["id"], {})
                    if "result" in x:
                        out.append(x["result"])
                    elif "error" in x:
                        out.append(None)  # execution revert / bad call
                    else:
                        out.append(None)
                return out
            except Exception as e:
                if a == tries - 1:
                    log(f"[rpc] batch failed after {tries}: {str(e)[:120]}")
                    return [None] * len(calls)
                time.sleep(0.8 * (a + 1))
        return [None] * len(calls)

rpc = Rpc(RPC)

def u(h, d=None):
    if h is None or h == "0x":
        return d
    try:
        return int(h, 16)
    except Exception:
        return d

def a(h):
    if not h or h == "0x":
        return None
    return "0x" + h[-40:]

SEL = {"token0": "0x0dfe1681", "token1": "0xd21220a7", "getReserves": "0x0902f1ac",
       "totalSupply": "0x18160ddd", "kLast": "0x7464fc3d", "balanceOf": "0x70a08231",
       "symbol": "0x95d89b41", "decimals": "0x313ce567", "name": "0x06fdde03"}

def enc(sel, arg=None):
    if arg is None:
        return sel
    return sel + arg[2:].lower().rjust(64, "0")

def dec_str(h):
    if not h or h == "0x":
        return None
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            off = int.from_bytes(b[:32], "big"); ln = int.from_bytes(b[off:off + 32], "big")
            if off + 32 + ln <= len(b):
                return b[off + 32:off + 32 + ln].decode("utf8", "replace")
        s = b.rstrip(b"\x00").decode("utf8", "replace")
        return s if s else None
    except Exception:
        return None

# ---------------------------------------------------------------- 1. pair list
def get_pairs():
    r = rpc.batch([("eth_call", [{"to": FACTORY, "data": SEL["totalSupply"][:10] + ""}, "latest"])])[0]
    # allPairsLength() = 0x574f2ba3
    r = rpc.batch([("eth_call", [{"to": FACTORY, "data": "0x574f2ba3"}, "latest"])])[0]
    n = u(r)
    log(f"[pairs] allPairsLength = {n}")
    pairs = []
    B = 10
    for i in range(0, n, B):
        calls = [("eth_call", [{"to": FACTORY, "data": enc("0x1e3dd18b", hex(i + j)[2:].rjust(64, "0"))}, "latest"]) for j in range(min(B, n - i))]
        res = rpc.batch(calls)
        for x in res:
            pa = a(x)
            if pa:
                pairs.append(pa)
        if i % 100 == 0:
            log(f"[pairs] fetched {len(pairs)}/{n}")
        time.sleep(0.2)
    return pairs

# ---------------------------------------------------------------- 2. per-pair state
def scan_pairs(pairs):
    out = {}
    B = 8
    for i in range(0, len(pairs), B):
        chunk = pairs[i:i + B]
        calls = []
        for pa in chunk:
            calls += [("eth_call", [{"to": pa, "data": SEL["token0"]}, "latest"]),
                      ("eth_call", [{"to": pa, "data": SEL["token1"]}, "latest"]),
                      ("eth_call", [{"to": pa, "data": SEL["getReserves"]}, "latest"]),
                      ("eth_call", [{"to": pa, "data": SEL["totalSupply"]}, "latest"]),
                      ("eth_call", [{"to": pa, "data": SEL["kLast"]}, "latest"])]
        res = rpc.batch(calls)
        for j, pa in enumerate(chunk):
            t0 = a(res[j * 5 + 0]); t1 = a(res[j * 5 + 1]); rv = res[j * 5 + 2]
            d = {"pair": pa, "token0": t0, "token1": t1}
            if rv and len(rv) >= 2 + 64 * 3:
                d["r0"] = u(rv[2:66]); d["r1"] = u(rv[66:130])
            d["lp_supply"] = u(res[j * 5 + 3])
            kl = res[j * 5 + 4]
            d["kLast"] = u(kl) if kl and kl != "0x" else None
            # balances (2 calls appended next batch round to keep batch small)
            d["_need_bal"] = True
            out[pa] = d
        if i % 160 == 0:
            log(f"[scan] {i}/{len(pairs)}")
        time.sleep(0.35)
    # balances in a second batched pass
    keys = list(out.keys())
    for i in range(0, len(keys), 8):
        chunk = keys[i:i + 8]
        calls = []
        for pa in chunk:
            d = out[pa]
            calls.append(("eth_call", [{"to": d["token0"], "data": enc(SEL["balanceOf"], pa)}, "latest"]))
            calls.append(("eth_call", [{"to": d["token1"], "data": enc(SEL["balanceOf"], pa)}, "latest"]))
        res = rpc.batch(calls)
        for j, pa in enumerate(chunk):
            d = out[pa]
            d["b0"] = u(res[j * 2 + 0]); d["b1"] = u(res[j * 2 + 1])
            if d.get("r0") is not None and d.get("b0") is not None:
                d["excess0"] = d["b0"] - d["r0"]
            if d.get("r1") is not None and d.get("b1") is not None:
                d["excess1"] = d["b1"] - d["r1"]
        if i % 160 == 0:
            log(f"[scan-bal] {i}/{len(keys)}")
        time.sleep(0.35)
    return out

# ---------------------------------------------------------------- 3. token metadata + prices
def token_meta(tokens):
    meta = {}
    toks = [t for t in tokens if t]
    B = 8
    for i in range(0, len(toks), B):
        chunk = toks[i:i + B]
        calls = []
        for t in chunk:
            calls += [("eth_call", [{"to": t, "data": SEL["symbol"]}, "latest"]),
                      ("eth_call", [{"to": t, "data": SEL["decimals"]}, "latest"]),
                      ("eth_call", [{"to": t, "data": SEL["totalSupply"]}, "latest"])]
        res = rpc.batch(calls)
        for j, t in enumerate(chunk):
            d = {"symbol": dec_str(res[j * 3 + 0]), "decimals": u(res[j * 3 + 1], 18) or 18,
                 "totalSupply": u(res[j * 3 + 2])}
            if d["decimals"] > 36:
                d["decimals"] = 18
            meta[t] = d
        time.sleep(0.2)
    return meta

def prices(tokens):
    px = {WETHW: 0.2726, USDT: 0.9993, USDC: 0.9998, BUSD: 0.9990, WBTC: 83409.21}  # fallbacks, overwritten by llama
    toks = sorted(set(t for t in tokens if t))
    B = 25
    for i in range(0, len(toks), B):
        q = ",".join(f"ethpow:{t}" for t in toks[i:i + B])
        url = "https://coins.llama.fi/prices/current/" + q
        for attempt in range(4):
            try:
                r = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=45).read())
                for k, v in (r.get("coins") or {}).items():
                    key = k.split(":")[-1].lower()
                    if v.get("price"):
                        px[key] = v["price"]
                break
            except Exception:
                time.sleep(2 + 2 * attempt)
    return px

# ---------------------------------------------------------------- 4. arb cycles
def out_amt(x, rin, rout):
    if x <= 0 or rin <= 0 or rout <= 0:
        return 0.0
    return (rout * FEE * x) / (rin + FEE * x)

def run_path(path, x):
    for (rin, rout) in path:
        x = out_amt(x, rin, rout)
        if x <= 0:
            return 0.0
    return x

def best_input(path, cap_raw):
    """golden search in log space for max (out - in)"""
    lo, hi = 1.0, max(cap_raw, 1.0)
    for _ in range(60):
        m1 = math.exp(math.log(lo) + (math.log(hi) - math.log(lo)) / 3)
        m2 = math.exp(math.log(lo) + 2 * (math.log(hi) - math.log(lo)) / 3)
        p1 = run_path(path, m1) - m1
        p2 = run_path(path, m2) - m2
        if p1 < p2:
            lo = m1
        else:
            hi = m2
    x = math.sqrt(lo * hi)
    return run_path(path, x) - x, x, run_path(path, x)

def build_cycles(pairs, meta, px, max_paths=400000, max_depth=3):
    edges = defaultdict(list)  # tok_in -> list of (tok_out, rin, rout, pair, dec_in, dec_out)
    for pa, d in pairs.items():
        if d.get("r0") in (None, 0) or d.get("r1") in (None, 0):
            continue
        t0, t1 = d["token0"], d["token1"]
        if not t0 or not t1:
            continue
        dec0 = meta.get(t0, {}).get("decimals", 18)
        dec1 = meta.get(t1, {}).get("decimals", 18)
        edges[t0].append((t1, d["r0"], d["r1"], pa, dec0, dec1))
        edges[t1].append((t0, d["r1"], d["r0"], pa, dec1, dec0))
    starts = [WETHW, USDT, USDC, BUSD, WBTC]
    # add top value tokens by balance*price
    tv = defaultdict(float)
    for pa, d in pairs.items():
        for tok, bal in ((d["token0"], d.get("b0")), (d["token1"], d.get("b1"))):
            if tok and bal:
                p = px.get(tok, 0)
                tv[tok] += bal / (10 ** meta.get(tok, {}).get("decimals", 18)) * p
    for tok, v in sorted(tv.items(), key=lambda x: -x[1])[:20]:
        if tok not in starts:
            starts.append(tok)
    results = []
    explored = 0
    seen_cycles = set()

    def dfs(start, node, path_edges, path_tokens, depth):
        nonlocal explored
        if explored > max_paths:
            return
        for (nxt, rin, rout, pair, dec_in, dec_out) in edges.get(node, []):
            explored += 1
            if nxt == start and len(path_edges) + 1 >= 2:
                key = tuple(sorted([e[2] for e in path_edges] + [pair]))
                if key in seen_cycles:
                    continue
                seen_cycles.add(key)
                p = [(rin2, rout2) for (rin2, rout2, _p, _di, _do) in path_edges] + [(rin, rout)]
                cap = min(rin for (rin, _) in p) * 9.0
                prof, x, outp = best_input(p, cap)
                if prof > 0:
                    pin = px.get(start, 0)
                    usd = prof / (10 ** meta.get(start, {}).get("decimals", 18)) * pin if pin else 0
                    results.append({
                        "start": start, "start_symbol": meta.get(start, {}).get("symbol"),
                        "path_pairs": [e[2] for e in path_edges] + [pair],
                        "tokens": path_tokens + [nxt],
                        "profit_raw": prof, "input_raw": x, "output_raw": outp,
                        "profit_usd_estimate": usd,
                    })
            elif len(path_edges) + 1 < max_depth and nxt != start and nxt not in path_tokens:
                dfs(start, nxt, path_edges + [(rin, rout, pair, dec_in, dec_out)], path_tokens + [nxt], depth + 1)

    for s in starts:
        if s not in edges:
            continue
        dfs(s, s, [], [s], 0)
        log(f"[arb] start {meta.get(s,{}).get('symbol')} {s[:10]} explored={explored} found={len(results)}")
    results.sort(key=lambda r: -r["profit_usd_estimate"])
    return results, explored

# ---------------------------------------------------------------- main
def main():
    t0 = time.time()
    blk = u(rpc.batch([("eth_blockNumber", [])])[0])
    log(f"[main] RPC={RPC} block={blk}")
    pairs_list = get_pairs()
    pairs = scan_pairs(pairs_list)
    json.dump({"block": blk, "factory": FACTORY, "pairs_count": len(pairs), "pairs": pairs},
              open(os.path.join(OUT, "pairs_fresh.json"), "w"), indent=1)

    # excess / one-sided
    excess = []
    onesided = []
    for pa, d in pairs.items():
        e0 = d.get("excess0"); e1 = d.get("excess1")
        if (e0 is not None and e0 > 0) or (e1 is not None and e1 > 0):
            excess.append(d)
        if d.get("r0") == 0 and (d.get("b1") or 0) > 0:
            onesided.append(d)
        if d.get("r1") == 0 and (d.get("b0") or 0) > 0:
            onesided.append(d)
    json.dump({"excess_pairs": excess, "one_sided_reserve_pairs": onesided},
              open(os.path.join(OUT, "excess.json"), "w"), indent=1)

    # fee mint estimate: feeLP = tc*(rootK - rootKLast)/(5*rootK + rootKLast)
    fee_rows = []
    for pa, d in pairs.items():
        if d.get("kLast") and d.get("r0") and d.get("r1") and d.get("lp_supply"):
            rk = math.sqrt(d["r0"] * d["r1"]); rkl = math.sqrt(d["kLast"])
            if rk > rkl:
                fee = d["lp_supply"] * (rk - rkl) / (5 * rk + rkl)
                fee_rows.append({"pair": pa, "token0": d["token0"], "token1": d["token1"],
                                 "fee_lp_raw": fee, "fee_lp_frac_of_supply": fee / d["lp_supply"],
                                 "r0": d["r0"], "r1": d["r1"], "lp_supply": d["lp_supply"]})
    fee_rows.sort(key=lambda x: -x["fee_lp_frac_of_supply"])
    json.dump(fee_rows, open(os.path.join(OUT, "fee_mint.json"), "w"), indent=1)

    # token meta for tokens with any nonzero balance
    toks = set()
    for pa, d in pairs.items():
        if d.get("b0"): toks.add(d["token0"])
        if d.get("b1"): toks.add(d["token1"])
    meta = token_meta(sorted(toks))
    px = prices(list(meta.keys()))

    # per-token totals
    totals = defaultdict(lambda: {"raw": 0, "usd": 0.0})
    for pa, d in pairs.items():
        for tok, bal in ((d["token0"], d.get("b0")), (d["token1"], d.get("b1"))):
            if tok and bal:
                dec = meta.get(tok, {}).get("decimals", 18)
                totals[tok]["raw"] += bal
                totals[tok]["usd"] += bal / (10 ** dec) * px.get(tok, 0)
    tot_rows = [{"token": t, "symbol": meta.get(t, {}).get("symbol"), "decimals": meta.get(t, {}).get("decimals"),
                 "amount": v["raw"] / (10 ** meta.get(t, {}).get("decimals", 18)), "usd": v["usd"],
                 "price": px.get(t, 0)} for t, v in totals.items()]
    tot_rows.sort(key=lambda x: -x["usd"])

    cycles, explored = build_cycles(pairs, meta, px)
    json.dump({"block": blk, "prices": px, "cycles": cycles[:200], "explored": explored},
              open(os.path.join(OUT, "arb_cycles.json"), "w"), indent=1)

    summary = {
        "block": blk, "rpc": RPC, "pairs_count": len(pairs),
        "tokens": len(meta), "excess_pairs": len(excess), "one_sided_pairs": len(onesided),
        "fee_mint_pairs": len(fee_rows),
        "total_usd_balances": sum(r["usd"] for r in tot_rows),
        "top_tokens": tot_rows[:25],
        "top_cycles": cycles[:25],
        "elapsed_sec": round(time.time() - t0, 1),
    }
    json.dump(summary, open(os.path.join(OUT, "scan_summary.json"), "w"), indent=1)

    with open(os.path.join(OUT, "pairs_summary.csv"), "w") as f:
        f.write("pair,token0,token1,r0,r1,b0,b1,lp_supply,excess0,excess1\n")
        for pa, d in pairs.items():
            f.write(",".join(str(x) for x in [pa, d.get("token0"), d.get("token1"), d.get("r0"), d.get("r1"),
                                              d.get("b0"), d.get("b1"), d.get("lp_supply"), d.get("excess0"), d.get("excess1")]) + "\n")
    log(f"[main] done in {summary['elapsed_sec']}s; pairs={len(pairs)} excess={len(excess)} onesided={len(onesided)} cycles={len(cycles)}")

if __name__ == "__main__":
    main()
