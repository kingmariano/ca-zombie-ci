#!/usr/bin/env python3
"""CI live-state snapshot for H-32 (Nest) + H-33 (Hybra) on HyperEVM.

Runs on GitHub Actions (public RPC). Writes ci-out/live_state.json.
Path-relative: script lives in <folder>/ci/, data in <folder>/analysis/.
"""
import json, os, sys, urllib.request, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "analysis"))
from hl_rpc import batch, block_number, enc_sel, eth_call  # noqa

OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

NEST_POOLS_FILE = os.path.join(ROOT, "analysis", "nest_pools_api.json")
HYBRA_POOLS_FILE = os.path.join(ROOT, "analysis", "hybra_pools.json")

NEST_PAIR_FACTORY = "0x889Fd0aDA8453C7619cD7f11E9029a1f0848Fdf5"
SEL_ALLPAIRS = "0x574f2ba3"
SEL_ALLPAIRS_AT = "0x1e3dd18b"  # allPairs(uint256)


def read_token_meta(tokens, bn):
    dec, sym = {}, {}
    calls, meta = [], []
    for t in tokens:
        for sig in ("decimals()", "symbol()"):
            calls.append(("eth_call", [{"to": t, "data": enc_sel(sig)}, hex(bn)]))
            meta.append((t, sig))
    res = batch(calls, chunk=15)
    for (t, sig), r in zip(meta, res):
        if sig == "decimals()":
            try:
                dec[t] = int(r, 16)
            except Exception:
                dec[t] = 18
        else:
            try:
                b = bytes.fromhex(r[2:])
                off = int.from_bytes(b[0:32], "big"); ln = int.from_bytes(b[off:off+32], "big")
                sym[t] = b[off+32:off+32+ln].decode(errors="replace")
            except Exception:
                sym[t] = "?"
    return dec, sym


def balances(pools, bn):
    calls, meta = [], []
    for p in pools:
        for t in (p.get("t0"), p.get("t1")):
            if not t:
                continue
            calls.append(("eth_call", [{"to": t, "data": enc_sel("balanceOf(address)") + p["pool"][2:].rjust(64, "0")}, hex(bn)]))
            meta.append((p["pool"], t))
    res = batch(calls, chunk=15)
    out = {}
    for (pool, t), r in zip(meta, res):
        out.setdefault(pool, {})[t] = int(r, 16) if r and r != "0x" else 0
    return out


def prices(tokens):
    ids = ",".join("hyperliquid:" + t for t in tokens)
    req = urllib.request.Request("https://coins.llama.fi/prices/current/" + ids, headers={"User-Agent": "Mozilla/5.0"})
    try:
        data = json.loads(urllib.request.urlopen(req, timeout=30).read())["coins"]
    except Exception as e:
        print("price fetch failed:", e)
        data = {}
    return {t: data.get("hyperliquid:" + t, {}).get("price") for t in tokens}


def main():
    bn = block_number()
    print("HyperEVM block:", bn)
    result = {"block": bn, "timestamp": datetime.datetime.utcnow().isoformat() + "Z", "protocols": {}}

    # ---------- Nest ----------
    nest_pools = json.load(open(NEST_POOLS_FILE))
    pools = []
    for p in nest_pools:
        t0 = (p.get("token0") or {}).get("tokenAddress")
        t1 = (p.get("token1") or {}).get("tokenAddress")
        pools.append({"pool": p["id"], "t0": t0, "t1": t1, "type": p.get("poolType")})
    # V2 factory enumeration (sanity)
    try:
        n = int(eth_call(NEST_PAIR_FACTORY, SEL_ALLPAIRS, hex(bn)), 16)
        v2 = []
        for i in range(n):
            r = eth_call(NEST_PAIR_FACTORY, SEL_ALLPAIRS_AT + f"{i:064x}", hex(bn))
            if r and r != "0x":
                v2.append("0x" + r[-40:])
        result["protocols"]["nest_v2_factory_pairs"] = v2
        print("Nest V2 pairs:", v2)
    except Exception as e:
        print("V2 enum failed:", e)

    toks = sorted({t for p in pools for t in (p["t0"], p["t1"]) if t})
    dec, sym = read_token_meta(toks, bn)
    bal = balances(pools, bn)
    px = prices(toks)
    total = 0.0
    rows = []
    for p in pools:
        v = 0.0; parts = {}
        for t in (p["t0"], p["t1"]):
            if not t:
                continue
            amt = bal.get(p["pool"], {}).get(t, 0) / (10 ** dec.get(t, 18))
            usd = amt * (px.get(t) or 0)
            v += usd
            parts[sym.get(t, t)] = {"token": t, "amount": amt, "usd": round(usd, 2)}
        total += v
        rows.append({"pool": p["pool"], "type": p["type"], "usd": round(v, 2), "tokens": parts})
    rows.sort(key=lambda r: -r["usd"])
    result["protocols"]["nest"] = {"pool_count": len(pools), "total_pool_usd": round(total, 2), "top_pools": rows[:20], "pools": rows}
    print(f"NEST pool balances: ${total:,.2f} over {len(pools)} pools")

    # ---------- Hybra ----------
    hy = json.load(open(HYBRA_POOLS_FILE))
    hpools = []
    for p in hy:
        t0 = p.get("token0()"); t1 = p.get("token1()")
        hpools.append({"pool": p["pool"], "t0": t0, "t1": t1})
    htoks = sorted({t for p in hpools for t in (p["t0"], p["t1"]) if t})
    hdec, hsym = read_token_meta(htoks, bn)
    hbal = balances(hpools, bn)
    hpx = prices(htoks)
    htotal = 0.0
    hrows = []
    for p in hpools:
        v = 0.0; parts = {}
        for t in (p["t0"], p["t1"]):
            if not t:
                continue
            amt = hbal.get(p["pool"], {}).get(t, 0) / (10 ** hdec.get(t, 18))
            usd = amt * (hpx.get(t) or 0)
            v += usd
            parts[hsym.get(t, t)] = {"token": t, "amount": amt, "usd": round(usd, 2)}
        htotal += v
        hrows.append({"pool": p["pool"], "usd": round(v, 2), "tokens": parts})
    hrows.sort(key=lambda r: -r["usd"])
    result["protocols"]["hybra"] = {"pool_count": len(hpools), "total_pool_usd": round(htotal, 2), "top_pools": hrows[:20], "pools": hrows}
    print(f"HYBRA pool balances: ${htotal:,.2f} over {len(hpools)} pools")

    with open(os.path.join(OUT, "live_state.json"), "w") as f:
        json.dump(result, f, indent=1)
    print("wrote ci-out/live_state.json")


if __name__ == "__main__":
    main()
