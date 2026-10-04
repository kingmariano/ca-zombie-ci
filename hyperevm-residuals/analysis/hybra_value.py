#!/usr/bin/env python3
"""Measure live token balances of all Hybra CL pools, price via DefiLlama, sum USD."""
import sys, json, urllib.request
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

POOLS = json.load(open("/home/heisenberg/CA/hyperevm-residuals/analysis/hybra_pools.json"))
DEC = {}
SYM = {}

def token_meta(t):
    if t in DEC: return
    out = batch([("eth_call", [{"to": t, "data": enc_sel("decimals()")}, "latest"]),
                 ("eth_call", [{"to": t, "data": enc_sel("symbol()")}, "latest"]),
                 ("eth_call", [{"to": t, "data": enc_sel("totalSupply()")}, "latest"])])
    try:
        DEC[t] = int(out[0], 16)
    except Exception:
        DEC[t] = 18
    try:
        b = bytes.fromhex(out[1][2:])
        off = int.from_bytes(b[0:32], "big"); ln = int.from_bytes(b[off:off+32], "big")
        SYM[t] = b[off+32:off+32+ln].decode(errors="replace")
    except Exception:
        SYM[t] = "?"

def main():
    bn = block_number(); print("block", bn)
    toks = set()
    for p in POOLS:
        for k in ("token0()", "token1()"):
            if p.get(k): toks.add(p[k])
    for t in toks: token_meta(t)
    print("tokens:", len(toks))
    # balances
    calls, meta = [], []
    for p in POOLS:
        for k in ("token0()", "token1()"):
            t = p.get(k)
            if not t: continue
            calls.append(("eth_call", [{"to": t, "data": enc_sel("balanceOf(address)") + p["pool"][2:].rjust(64, "0")}, hex(bn)]))
            meta.append((p["pool"], k, t))
    res = batch(calls, chunk=15)
    bal = {}
    for (pool, k, t), r in zip(meta, res):
        bal.setdefault(pool, {})[k] = int(r, 16) if r and r != "0x" else 0
    # prices
    price_ids = ",".join("hyperliquid:" + t for t in toks)
    req = urllib.request.Request("https://coins.llama.fi/prices/current/" + price_ids, headers={"User-Agent": "Mozilla/5.0"})
    prices = json.loads(urllib.request.urlopen(req, timeout=30).read())["coins"]
    total = 0.0
    rows = []
    for p in POOLS:
        pool = p["pool"]
        v = 0.0; parts = []
        for k in ("token0()", "token1()"):
            t = p.get(k)
            if not t: continue
            amt = bal.get(pool, {}).get(k, 0) / (10 ** DEC.get(t, 18))
            pi = prices.get("hyperliquid:" + t, {})
            usd = amt * pi.get("price", 0)
            v += usd
            parts.append(f"{SYM.get(t,'?')}={amt:.6g}(${usd:,.0f})")
        if v > 0.5:
            rows.append({"pool": pool, "usd": round(v, 2), "parts": parts, "fee": p.get("fee()"), "gauge": p.get("gauge()"), "liquidity": p.get("liquidity()")})
        total += v
    rows.sort(key=lambda r: -r["usd"])
    print(f"TOTAL Hybra pool balances: ${total:,.2f}")
    for r in rows[:25]:
        print(f"  {r['pool']} ${r['usd']:>12,.0f} fee={r['fee']} {' '.join(r['parts'])}")
    json.dump({"block": bn, "total_usd": round(total, 2), "rows": rows, "tokens": {t: {"symbol": SYM.get(t), "decimals": DEC.get(t), "price": prices.get("hyperliquid:" + t, {}).get("price")} for t in toks}}, open("/home/heisenberg/CA/hyperevm-residuals/analysis/hybra_value.json", "w"), indent=1)
    print("saved hybra_value.json")

if __name__ == "__main__":
    main()
