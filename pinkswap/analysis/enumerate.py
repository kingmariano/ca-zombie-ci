#!/usr/bin/env python3
"""
PinkSwap (BSC) live-state enumeration — Phase 2 deep dive.

For every pair of factory 0x7d2ce25c28334e40f37b2a068ec8d5a59f11ea54:
  token0/token1, getReserves, actual token balances of the pair, LP totalSupply.
Excess (balance - reserve) is the classic unprivileged skim() extraction vector.
Also reads feeTo/feeToSetter, code status, and prices via DefiLlama.

Read-only. Never writes RPC URLs or secrets into outputs.
Usage: python3 enumerate.py [blockTag]   (default: latest)
"""
import json, os, sys, time
import urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "analysis")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-ci"}

RPC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"
FALLBACKS = ["https://bsc.drpc.org", "https://1rpc.io/bnb", "https://bsc-rpc.publicnode.com"]
FACTORY = "0x7d2ce25c28334e40f37b2a068ec8d5a59f11ea54"

SEL = {
    "allPairsLength()": "0x574f2ba3",
    "allPairs(uint256)": "0x1e3dd18b",
    "getPair(address,address)": "0xe6a43905",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "totalSupply()": "0x18160ddd",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "balanceOf(address)": "0x70a08231",
    "feeTo()": "0x017e7e58",
    "feeToSetter()": "0x094b7415",
    "kLast()": "0x7464fc3d",
    "factory()": "0xc45a0155",
}

def _urls():
    return list(dict.fromkeys([RPC] + FALLBACKS))

def rpc(method, params, timeout=25):
    last = None
    for url in _urls():
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
        except Exception as e:
            last = type(e).__name__
    raise RuntimeError(f"rpc fail {method}: {last}")

def batch(calls, timeout=90, tries=4):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for attempt in range(tries):
        for url in _urls():
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
                last = type(e).__name__
        time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"batch fail: {last}")

def hexint(h):
    try: return int(h, 16)
    except Exception: return None

def dec_addr(h):
    if not h or not isinstance(h, str) or len(h) < 42: return None
    a = "0x" + h[-40:]
    return a if a != "0x" + "0"*40 else None

def dec_str(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], "big")
            return b[64:64+ln].decode("utf-8", "replace")
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None

def enc_uint(n): return hex(n)[2:].rjust(64, "0")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

def llama_prices(addrs):
    out = {}
    addrs = list(dict.fromkeys(a.lower() for a in addrs if a and a.startswith("0x")))
    for i in range(0, len(addrs), 80):
        chunk = addrs[i:i+80]
        try:
            url = "https://coins.llama.fi/prices/current/" + ",".join(f"bsc:{a}" for a in chunk)
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode())
            for k, v in (d.get("coins") or {}).items():
                a = k.split(":")[-1].lower()
                if v.get("price") is not None:
                    out[a] = {"price": float(v["price"]), "symbol": v.get("symbol"), "conf": v.get("confidence")}
        except Exception:
            pass
    return out

def main():
    os.makedirs(OUT, exist_ok=True)
    block_tag = sys.argv[1] if len(sys.argv) > 1 else "latest"
    blk = hexint(rpc("eth_blockNumber", [])) if block_tag == "latest" else hexint(block_tag)
    if block_tag != "latest":
        blk = hexint(block_tag)
    tag = hex(blk) if block_tag == "latest" else block_tag
    print("block", blk, flush=True)

    fac_info = {"factory": FACTORY, "block": blk}
    for name, sel in (("feeTo", SEL["feeTo()"]), ("feeToSetter", SEL["feeToSetter()"])):
        try:
            fac_info[name] = dec_addr(rpc("eth_call", [{"to": FACTORY, "data": sel}, tag]))
        except Exception as e:
            fac_info[name] = f"err:{e}"
    fac_info["code_len"] = len(rpc("eth_getCode", [FACTORY, tag])) // 2
    try:
        n = hexint(rpc("eth_call", [{"to": FACTORY, "data": SEL["allPairsLength()"]}, tag]))
    except Exception as e:
        raise SystemExit(f"allPairsLength failed: {e}")
    fac_info["n_pairs"] = n
    print("pairs", n, flush=True)

    pairs = []
    for i in range(0, n, 100):
        chunk = list(range(i, min(i+100, n)))
        rs = batch([("eth_call", [{"to": FACTORY, "data": SEL["allPairs(uint256)"] + enc_uint(x)}, tag]) for x in chunk])
        for r in rs:
            a = dec_addr(r)
            if a: pairs.append(a)
    pairs = list(dict.fromkeys(pairs))
    print("pairs fetched", len(pairs), flush=True)

    # per-pair: token0, token1, reserves, totalSupply
    recs = []
    for i in range(0, len(pairs), 25):
        chunk = pairs[i:i+25]
        calls = []
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["token0()"]}, tag]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["token1()"]}, tag]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["getReserves()"]}, tag]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["totalSupply()"]}, tag]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["factory()"]}, tag]))
        rs = batch(calls)
        L = len(chunk)
        for j, p in enumerate(chunk):
            t0 = dec_addr(rs[j]); t1 = dec_addr(rs[L+j])
            rr = rs[2*L+j] if isinstance(rs[2*L+j], str) else None
            ts = hexint(rs[3*L+j]) if isinstance(rs[3*L+j], str) else None
            f = dec_addr(rs[4*L+j]) if isinstance(rs[4*L+j], str) else None
            if not (t0 and t1 and rr and len(rr) >= 130):
                recs.append({"pair": p, "error": "read-failed"}); continue
            recs.append({"pair": p, "token0": t0, "token1": t1,
                         "r0": int(rr[2:66], 16), "r1": int(rr[66:130], 16),
                         "lp_supply": ts, "pair_factory": f})

    # balances of pair for both tokens + decimals + symbols for all tokens
    toks = []
    for r in recs:
        if "token0" in r:
            toks += [r["token0"], r["token1"]]
    toks = list(dict.fromkeys(toks))
    meta = {}
    for i in range(0, len(toks), 50):
        chunk = toks[i:i+50]
        rs = batch([("eth_call", [{"to": t, "data": SEL["decimals()"]}, tag]) for t in chunk]
                   + [("eth_call", [{"to": t, "data": SEL["symbol()"]}, tag]) for t in chunk])
        for j, t in enumerate(chunk):
            d = hexint(rs[j]) if isinstance(rs[j], str) else None
            meta[t] = {"decimals": d if (d is not None and 0 <= d <= 36) else 18,
                       "symbol": (dec_str(rs[len(chunk)+j]) or "?")[:24] if isinstance(rs[len(chunk)+j], str) else "?"}

    for i in range(0, len(recs), 40):
        chunk = [r for r in recs if "token0" in r][i:i+40]
        calls = []
        for r in chunk: calls.append(("eth_call", [{"to": r["token0"], "data": SEL["balanceOf(address)"] + enc_addr(r["pair"])}, tag]))
        for r in chunk: calls.append(("eth_call", [{"to": r["token1"], "data": SEL["balanceOf(address)"] + enc_addr(r["pair"])}, tag]))
        rs = batch(calls)
        L = len(chunk)
        for j, r in enumerate(chunk):
            r["b0"] = hexint(rs[j]) if isinstance(rs[j], str) else None
            r["b1"] = hexint(rs[L+j]) if isinstance(rs[L+j], str) else None

    prices = llama_prices(toks)
    tot_reserve_usd = 0.0
    tot_excess_usd = 0.0
    tot_lp_usd = 0.0
    excess_rows = []
    for r in recs:
        if "token0" not in r: continue
        t0, t1 = r["token0"], r["token1"]
        d0, d1 = meta[t0]["decimals"], meta[t1]["decimals"]
        p0 = prices.get(t0, {}).get("price", 0.0)
        p1 = prices.get(t1, {}).get("price", 0.0)
        r["sym0"], r["sym1"] = meta[t0]["symbol"], meta[t1]["symbol"]
        r["dec0"], r["dec1"] = d0, d1
        r["price0"], r["price1"] = p0, p1
        v_res = (r["r0"] / 10**d0) * p0 + (r["r1"] / 10**d1) * p1
        r["reserve_usd"] = round(v_res, 2)
        if r.get("b0") is not None:
            ex0 = max(0, r["b0"] - r["r0"]); ex1 = max(0, r["b1"] - r["r1"])
        else:
            ex0 = ex1 = 0
        r["excess0"], r["excess1"] = ex0, ex1
        v_ex = (ex0 / 10**d0) * p0 + (ex1 / 10**d1) * p1
        r["excess_usd"] = round(v_ex, 2)
        tot_reserve_usd += v_res
        tot_excess_usd += v_ex
        if v_ex > 1 or ex0 > 0 or ex1 > 0:
            excess_rows.append({"pair": r["pair"], "sym0": r["sym0"], "sym1": r["sym1"],
                                "excess0": ex0, "excess1": ex1, "excess_usd": round(v_ex, 2),
                                "excess0_human": ex0 / 10**d0, "excess1_human": ex1 / 10**d1})
    excess_rows.sort(key=lambda x: -x["excess_usd"])

    out = {
        "factory": fac_info,
        "block": blk,
        "n_pairs": len(recs),
        "prices_used": {k: v for k, v in prices.items()},
        "totals": {
            "reserves_usd_llama_priced": round(tot_reserve_usd, 2),
            "excess_usd": round(tot_excess_usd, 2),
            "pairs_with_excess": len(excess_rows),
        },
        "top_excess": excess_rows[:40],
        "top_pairs_by_reserve": sorted(
            [{"pair": r["pair"], "sym0": r.get("sym0"), "sym1": r.get("sym1"),
              "reserve_usd": r.get("reserve_usd"), "excess_usd": r.get("excess_usd"),
              "lp_supply": r.get("lp_supply"), "r0": r.get("r0"), "r1": r.get("r1"),
              "dec0": r.get("dec0"), "dec1": r.get("dec1"), "b0": r.get("b0"), "b1": r.get("b1")}
             for r in recs if "token0" in r], key=lambda x: -(x["reserve_usd"] or 0))[:25],
        "all_pairs": [{"pair": r["pair"], "sym0": r.get("sym0"), "sym1": r.get("sym1"),
                       "reserve_usd": r.get("reserve_usd"), "excess_usd": r.get("excess_usd"),
                       "lp_supply": r.get("lp_supply"), "error": r.get("error")}
                      for r in recs],
        "unpriced_tokens": [t for t in toks if t not in prices],
    }
    fn = os.path.join(OUT, f"enumeration_{blk}.json")
    json.dump(out, open(fn, "w"), indent=1)
    print("wrote", fn, flush=True)
    print("reserves_usd", out["totals"]["reserves_usd_llama_priced"],
          "excess_usd", out["totals"]["excess_usd"], "pairs_with_excess", out["totals"]["pairs_with_excess"], flush=True)
    print("top excess:", json.dumps(excess_rows[:10], indent=1), flush=True)

if __name__ == "__main__":
    main()
