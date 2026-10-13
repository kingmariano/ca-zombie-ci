#!/usr/bin/env python3
"""
BurgerSwap (BSC) live-state enumeration for the L2 Phase-2 deep dive.

Reads the DemaxFactory pair set (922 pairs), for every pair:
  token0/token1, getReserves, ERC20 balances of the pair, LP totalSupply,
  DGAS-adjusted balances (balance - remainReward) for BURGER pairs,
prices every token via DefiLlama, computes
  reserve_usd  (LP-owned value at the AMM's own reserves)
  excess_usd   (balance - reserve, the part not reflected in reserves)
and flags pairs where a token looks attacker-inflatable (public mint-like
selector present in bytecode) -> candidate for the balance-inflation attack.

Read-only. No secrets written. Writes JSON to ci-out/.
"""
import json, os, re, sys, time
import urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "ci-out")
UA = {"User-Agent": "Mozilla/5.0 zombie-ci", "Content-Type": "application/json"}
URL_RE = re.compile(r"https?://\S+")

def redact(s):
    return URL_RE.sub("<url-redacted>", str(s))[:300]

def env(*names):
    for n in names:
        v = os.environ.get(n)
        if v:
            return v
    return None

FACTORY = "0x8a1E9d3aEbBBd5bA2A64d3355A48dD5E9b511256"
BURGER = "0xae9269f27437f0fcbc232d39ec814844a51d6b8f"
PLATFORM = "0xB099D7dbC415bf5491B0ca6fdCcFddF8b7EDCE12"
RPC_URLS = [u for u in [env("BSC_RPC_URL"), "https://bsc-rpc.publicnode.com",
                        "https://bsc.drpc.org", "https://binance.llamarpc.com"] if u]

def rpc(method, params, timeout=30):
    last = None
    for url in RPC_URLS:
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
        except Exception as e:
            last = redact(e)
    raise RuntimeError(f"rpc fail {method}: {redact(last)}")

def rpc_batch(calls, timeout=120):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for url in RPC_URLS:
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
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
    raise RuntimeError(f"batch fail: {redact(last)}")

def eth_call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def enc_uint(n):
    return hex(n)[2:].rjust(64, "0")

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def h2i(h):
    try:
        return int(h, 16)
    except Exception:
        return None

def dec_addr(h):
    if not h or not isinstance(h, str) or len(h) < 42:
        return None
    a = "0x" + h[-40:]
    return None if a == "0x0000000000000000000000000000000000000000" else a

def dec_str(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], "big")
            if 0 < ln <= 64:
                return b[64:64 + ln].decode("utf-8", "replace")
            return ""
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return ""

SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "remainReward": "0x1485ff78",
    "sync": "0xfff6cae9",
    "swapPrecondition": "0xddd377ac",
    "getAmountsOut": "0xd06ca61f",
    "swapExactTokensForTokens": "0x38ed1739",
    "addLiquidity": "0x7ae06e58",
    "removeLiquidity": "0xbaa2abde",
    "mintReward": "0x174f57af",
    "claimReward": "0x4953c782",
    "takeWithAddress": "0x6622c838",
}

# keccak256 selectors computed with `cast sig` (recorded for reproducibility)
MINT_SELECTORS = {
    "mint(address,uint256)": "40c10f19",
    "mint(uint256)": "a0712d68",
    "mint()": "1249c58b",
    "mint(address)": "6a627842",
    "mintTo(address,uint256)": "449a52f8",
    "print(address,uint256)": "ac685539",
    "issue(uint256)": "cc872b66",
    "generate(uint256)": "4a7dd523",
    "airdrop(address,uint256)": "8ba4cc3c",
}
OWNER_SELECTORS = {"owner()": "8da5cb5b", "getOwner()": "893d20e8"}

def llama_prices(addrs):
    out = {}
    addrs = list(dict.fromkeys(a.lower() for a in addrs if a and a.startswith("0x")))
    for i in range(0, len(addrs), 80):
        chunk = addrs[i:i + 80]
        try:
            url = "https://coins.llama.fi/prices/current/" + ",".join(f"bsc:{a}" for a in chunk)
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read().decode())
            for k, v in (d.get("coins") or {}).items():
                a = k.split(":")[-1].lower()
                if v.get("price") is not None:
                    out[a] = {"price": float(v["price"]), "symbol": v.get("symbol"), "decimals": v.get("decimals")}
        except Exception as e:
            print("llama chunk fail", redact(e), flush=True)
        time.sleep(0.4)
    return out

def main():
    os.makedirs(OUT, exist_ok=True)
    block = h2i(rpc("eth_blockNumber", []))
    print("block:", block, flush=True)
    n = h2i(eth_call(FACTORY, SEL["allPairsLength"]))
    print("allPairsLength:", n, flush=True)

    # 1) all pairs
    idxs = list(range(n))
    pairs = []
    for i in range(0, len(idxs), 100):
        chunk = idxs[i:i + 100]
        calls = [("eth_call", [{"to": FACTORY, "data": SEL["allPairs"] + enc_uint(x)}, "latest"]) for x in chunk]
        for r in rpc_batch(calls):
            a = dec_addr(r) if isinstance(r, str) else None
            if a:
                pairs.append(a.lower())
    print("pairs:", len(pairs), flush=True)

    # 2) token0/token1 + reserves + totalSupply
    recs = {}
    for i in range(0, len(pairs), 60):
        chunk = pairs[i:i + 60]
        L = len(chunk)
        calls = []
        for p in chunk:
            calls.append(("eth_call", [{"to": p, "data": SEL["token0"]}, "latest"]))
        for p in chunk:
            calls.append(("eth_call", [{"to": p, "data": SEL["token1"]}, "latest"]))
        for p in chunk:
            calls.append(("eth_call", [{"to": p, "data": SEL["getReserves"]}, "latest"]))
        for p in chunk:
            calls.append(("eth_call", [{"to": p, "data": SEL["totalSupply"]}, "latest"]))
        rs = rpc_batch(calls, timeout=180)
        for j, p in enumerate(chunk):
            t0 = dec_addr(rs[j]) if isinstance(rs[j], str) else None
            t1 = dec_addr(rs[L + j]) if isinstance(rs[L + j], str) else None
            rr = rs[2 * L + j] if isinstance(rs[2 * L + j], str) else None
            ts = rs[3 * L + j] if isinstance(rs[3 * L + j], str) else None
            r0 = r1 = None
            if rr and len(rr) >= 130:
                r0 = int(rr[2:66], 16)
                r1 = int(rr[66:130], 16)
            recs[p] = {"pair": p, "token0": t0, "token1": t1, "reserve0": r0, "reserve1": r1,
                       "totalSupply": h2i(ts) if isinstance(ts, str) else None}
        if (i // 60) % 3 == 0:
            print(f"  pair meta {i + len(chunk)}/{len(pairs)}", flush=True)

    # 3) token balances held by each pair + DGAS remainReward + DGAS token-level pending
    for i in range(0, len(pairs), 60):
        chunk = pairs[i:i + 60]
        calls = []
        for p in chunk:
            r = recs[p]
            if r["token0"]:
                calls.append(("eth_call", [{"to": r["token0"], "data": SEL["balanceOf"] + enc_addr(p)}, "latest"]))
            else:
                calls.append(("eth_call", [{"to": p, "data": "0x"}, "latest"]))
        for p in chunk:
            r = recs[p]
            if r["token1"]:
                calls.append(("eth_call", [{"to": r["token1"], "data": SEL["balanceOf"] + enc_addr(p)}, "latest"]))
            else:
                calls.append(("eth_call", [{"to": p, "data": "0x"}, "latest"]))
        for p in chunk:
            r = recs[p]
            if r["token0"] == BURGER or r["token1"] == BURGER:
                calls.append(("eth_call", [{"to": p, "data": SEL["remainReward"]}, "latest"]))
            else:
                calls.append(("eth_call", [{"to": p, "data": "0x"}, "latest"]))
        for p in chunk:
            calls.append(("eth_call", [{"to": BURGER, "data": SEL["takeWithAddress"] + enc_addr(p)}, "latest"]))
        rs = rpc_batch(calls, timeout=180)
        L = len(chunk)
        for j, p in enumerate(chunk):
            r = recs[p]
            b0 = h2i(rs[j]) if isinstance(rs[j], str) else None
            b1 = h2i(rs[L + j]) if isinstance(rs[L + j], str) else None
            rem = h2i(rs[2 * L + j]) if isinstance(rs[2 * L + j], str) else None
            take = h2i(rs[3 * L + j]) if isinstance(rs[3 * L + j], str) else None
            r["bal0"] = b0
            r["bal1"] = b1
            r["remainReward"] = rem if rem else 0
            r["dgas_token_level_pending"] = take if take else 0
            # DGAS-adjusted balance (pair excludes remainReward from reserves)
            if r["token0"] == BURGER and b0 is not None:
                r["adj0"] = max(0, b0 - r["remainReward"])
            else:
                r["adj0"] = b0
            if r["token1"] == BURGER and b1 is not None:
                r["adj1"] = max(0, b1 - r["remainReward"])
            else:
                r["adj1"] = b1
            r["excess0"] = max(0, (r["adj0"] or 0) - (r["reserve0"] or 0))
            r["excess1"] = max(0, (r["adj1"] or 0) - (r["reserve1"] or 0))

    # 4) token metadata + bytecode selector scan
    toks = set()
    for r in recs.values():
        if r["token0"]:
            toks.add(r["token0"])
        if r["token1"]:
            toks.add(r["token1"])
    toks = sorted(toks)
    print("unique tokens:", len(toks), flush=True)
    meta = {}
    for i in range(0, len(toks), 60):
        chunk = toks[i:i + 60]
        calls = []
        for t in chunk:
            calls.append(("eth_call", [{"to": t, "data": SEL["symbol"]}, "latest"]))
        for t in chunk:
            calls.append(("eth_call", [{"to": t, "data": SEL["decimals"]}, "latest"]))
        rs = rpc_batch(calls)
        L = len(chunk)
        for j, t in enumerate(chunk):
            sym = dec_str(rs[j]) if isinstance(rs[j], str) else ""
            dec = h2i(rs[L + j]) if isinstance(rs[L + j], str) else None
            meta[t] = {"symbol": sym, "decimals": dec if dec is not None and 0 <= dec <= 36 else 18}
    # bytecode
    codes = {}
    for i in range(0, len(toks), 40):
        chunk = toks[i:i + 40]
        rs = rpc_batch([("eth_getCode", [t, "latest"]) for t in chunk])
        for t, c in zip(chunk, rs):
            codes[t] = c if isinstance(c, str) else "0x"
    print("codes fetched", flush=True)
    infl = {}
    for t in toks:
        code = codes.get(t, "0x").lower()
        found = [name for name, sel in MINT_SELECTORS.items() if sel in code]
        owners = [name for name, sel in OWNER_SELECTORS.items() if sel in code]
        owner_addr = None
        for oname in owners:
            sel = OWNER_SELECTORS[oname]
            try:
                r = eth_call(t, "0x" + sel)
                a = dec_addr(r) if isinstance(r, str) else None
                if a:
                    owner_addr = a
                    break
            except Exception:
                pass
        infl[t] = {"mint_selectors": found, "owner_selector": bool(owners), "owner": owner_addr,
                   "code_size": (len(code) - 2) // 2}

    # 5) prices
    prices = llama_prices(toks)
    print("prices:", len(prices), "of", len(toks), flush=True)

    # 6) score
    out_pairs = []
    tot_reserve = tot_excess = tot_burger_side = 0.0
    for p, r in recs.items():
        t0, t1 = r["token0"], r["token1"]
        p0 = prices.get(t0, {}).get("price", 0.0) if t0 else 0.0
        p1 = prices.get(t1, {}).get("price", 0.0) if t1 else 0.0
        d0 = meta.get(t0, {}).get("decimals", 18) if t0 else 18
        d1 = meta.get(t1, {}).get("decimals", 18) if t1 else 18
        r0 = (r["reserve0"] or 0) / 10 ** d0
        r1 = (r["reserve1"] or 0) / 10 ** d1
        b0 = (r["adj0"] or 0) / 10 ** d0
        b1 = (r["adj1"] or 0) / 10 ** d1
        e0 = (r["excess0"] or 0) / 10 ** d0
        e1 = (r["excess1"] or 0) / 10 ** d1
        v0, v1 = r0 * p0, r1 * p1
        ev0, ev1 = e0 * p0, e1 * p1
        m0 = infl.get(t0, {}).get("mint_selectors", []) if t0 else []
        m1 = infl.get(t1, {}).get("mint_selectors", []) if t1 else []
        # value extractable by inflating the *other* side
        # if t0 inflatable -> attacker drains t1 side; if t1 inflatable -> drains t0 side
        drain = 0.0
        if m0:
            drain += v1
        if m1:
            drain += v0
        rec = {
            "pair": p, "token0": t0, "token1": t1,
            "sym0": meta.get(t0, {}).get("symbol"), "sym1": meta.get(t1, {}).get("symbol"),
            "dec0": d0, "dec1": d1,
            "reserve0": r0, "reserve1": r1, "bal0": b0, "bal1": b1,
            "excess0": e0, "excess1": e1,
            "remainReward": r["remainReward"],
            "dgas_token_level_pending": r.get("dgas_token_level_pending", 0),
            "totalSupply_lp": (r["totalSupply"] or 0) / 1e18,
            "price0": p0, "price1": p1,
            "usd_reserve": round(v0 + v1, 2),
            "usd_excess": round(ev0 + ev1, 2),
            "mint0": m0, "mint1": m1,
            "usd_drain_if_inflatable": round(drain, 2),
        }
        out_pairs.append(rec)
        tot_reserve += v0 + v1
        tot_excess += ev0 + ev1
    out_pairs.sort(key=lambda x: -x["usd_reserve"])
    json.dump(out_pairs, open(os.path.join(OUT, "pairs.json"), "w"), indent=1)

    candidates = [r for r in out_pairs if r["usd_drain_if_inflatable"] >= 20]
    candidates.sort(key=lambda x: -x["usd_drain_if_inflatable"])
    json.dump(candidates, open(os.path.join(OUT, "candidates.json"), "w"), indent=1)

    top_excess = sorted([r for r in out_pairs if r["usd_excess"] >= 1], key=lambda x: -x["usd_excess"])
    burger_price = prices.get(BURGER, {}).get("price", 0.0)
    rem_total = sum(r["remainReward"] for r in out_pairs) / 1e18
    take_total = sum(r["dgas_token_level_pending"] for r in out_pairs) / 1e18
    summary = {
        "block": block,
        "n_pairs": len(recs),
        "n_priced_tokens": len(prices),
        "n_tokens": len(toks),
        "usd_reserve_total": round(tot_reserve, 2),
        "usd_excess_total": round(tot_excess, 2),
        "n_pairs_reserve_ge_1": len([r for r in out_pairs if r["usd_reserve"] >= 1]),
        "n_pairs_excess_ge_1": len(top_excess),
        "burger_price": burger_price,
        "remainReward_total_burger": rem_total,
        "remainReward_total_usd": round(rem_total * burger_price, 2),
        "dgas_token_level_pending_total_burger": take_total,
        "dgas_token_level_pending_total_usd": round(take_total * burger_price, 2),
        "top_pairs": out_pairs[:20],
        "top_excess": top_excess[:20],
        "n_mintable_tokens": len([t for t in toks if infl.get(t, {}).get("mint_selectors")]),
        "top_drain_candidates": candidates[:25],
        "tokens": {t: {**meta.get(t, {}), **infl.get(t, {}), "price": prices.get(t, {}).get("price")} for t in toks},
    }
    json.dump(summary, open(os.path.join(OUT, "summary.json"), "w"), indent=1)
    print("SUMMARY", json.dumps({k: v for k, v in summary.items() if k not in ("top_pairs", "tokens", "top_excess", "top_drain_candidates")}), flush=True)
    print("top pairs:")
    for r in out_pairs[:15]:
        print(f"  {r['pair']} {r['sym0']}/{r['sym1']} reserve=${r['usd_reserve']} excess=${r['usd_excess']} drain=${r['usd_drain_if_inflatable']} mint0={r['mint0']} mint1={r['mint1']}", flush=True)
    print("top excess:")
    for r in top_excess[:10]:
        print(f"  {r['pair']} {r['sym0']}/{r['sym1']} excess=${r['usd_excess']} ({r['excess0']} {r['sym0']}, {r['excess1']} {r['sym1']})", flush=True)
    print("top drain candidates:")
    for r in candidates[:15]:
        print(f"  {r['pair']} {r['sym0']}/{r['sym1']} drain=${r['usd_drain_if_inflatable']} mint0={r['mint0']} mint1={r['mint1']} reserve=${r['usd_reserve']}", flush=True)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
