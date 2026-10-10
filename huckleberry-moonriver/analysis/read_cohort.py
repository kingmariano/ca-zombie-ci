#!/usr/bin/env python3
"""Enumerate Moonswap + Huckleberry AMM pairs and Huckleberry lending markets
at the frozen Moonriver head (17,381,654). Read-only. Saves JSON evidence."""
import json, sys, time
from mr import Rpc, SEL, enc_uint, enc_addr, dec_addr, dec_uint

R = Rpc()
HEAD = R.head

MOONSWAP_FACTORY = "0x056973f631a5533470143bb7010c9229c19c04d2"
HUCK_FACTORY = "0x017603c8f29f7f6394737628a93c57ffba1b7256"
HUCK_COMPTROLLER = "0xcffef313b69d83cb9ba35d9c0f882b027b846ddc"
HUCK_MARKETS = [
    "0x455D0c83623215095849AbCF7Cc046f78E3EDAe0",
    "0x7dcf13928EE7EfD5DD4789888d9baEf555575399",
    "0xd275c08c5C5cEDd5617ECAca5C71eC560715f49C",
    "0x0dA4B57c2BFc2AFCf6f63cDC89DAe588C943C5B6",
    "0x809eD65E30500cdFFfE4e25B8d3019DEE21230cc",
    "0x56E49Fd915a9c26B37d22A82C4A276827F31DCD5",
    "0x68c5c3F507eB76EbEd75CC28632D7C1D5B3E7E83",
    "0x12AE8068f195453f25A42f097721929F698F57fC",
    "0xd629D7ccaAE2338F13e8253B5232d5Ad4342ea22",
    "0xFBd7c66b72b9DC3F32c783548CEdCfb22F15d875",
    "0x517a37861EF1c60BA481a3D694890DDfE508e255",
]


def dec_str(word):
    if not word or word == "0x":
        return None
    try:
        b = bytes.fromhex(word[2:])
        if len(b) >= 64:
            off = int.from_bytes(b[0:32], "big")
            if off == 32 and len(b) >= 64:
                ln = int.from_bytes(b[off:off + 32], "big")
                if 0 <= ln <= 64:
                    return b[off + 32:off + 32 + ln].decode("utf-8", "replace")
        # bytes32 style
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None


def enumerate_dex(factory, label):
    n = dec_uint(R.call(factory, SEL["allPairsLength"]))
    print(f"[{label}] allPairsLength={n}", flush=True)
    pairs = []
    for s in range(0, n, 200):
        idxs = list(range(s, min(s + 200, n)))
        res = R.batch_call([(factory, enc_uint(SEL["allPairs"], i)) for i in idxs], chunk=40)
        pairs.extend(dec_addr(w) for w in res)
    print(f"[{label}] pairs fetched={len(pairs)}", flush=True)
    # tokens
    t0 = R.batch_call([(p, SEL["token0"]) for p in pairs], chunk=40)
    t1 = R.batch_call([(p, SEL["token1"]) for p in pairs], chunk=40)
    tokens = {}
    for i, p in enumerate(pairs):
        a, b = dec_addr(t0[i]), dec_addr(t1[i])
        tokens.setdefault(a, None)
        tokens.setdefault(b, None)
    uniq = sorted(tokens)
    print(f"[{label}] unique tokens={len(uniq)}", flush=True)
    syms = R.batch_call([(t, SEL["symbol"]) for t in uniq], chunk=40)
    decs = R.batch_call([(t, SEL["decimals"]) for t in uniq], chunk=40)
    meta = {}
    for i, t in enumerate(uniq):
        meta[t] = {"symbol": dec_str(syms[i]), "decimals": dec_uint(decs[i])}
    # balances: pair's balance of each of its two tokens
    bal_calls = []
    bal_map = []
    for i, p in enumerate(pairs):
        for tok in (dec_addr(t0[i]), dec_addr(t1[i])):
            if tok:
                bal_calls.append((tok, enc_addr(SEL["balanceOf"], p)))
                bal_map.append((i, tok))
    bals = R.batch_call(bal_calls, chunk=40)
    out = {"factory": factory, "head": HEAD, "pair_count": n,
           "token_meta": meta, "pairs": []}
    bal_by = {}
    for (i, tok), w in zip(bal_map, bals):
        bal_by[(i, tok)] = dec_uint(w)
    for i, p in enumerate(pairs):
        a, b = dec_addr(t0[i]), dec_addr(t1[i])
        out["pairs"].append({
            "pair": p,
            "token0": a, "symbol0": meta.get(a, {}).get("symbol"), "decimals0": meta.get(a, {}).get("decimals"),
            "balance0": bal_by.get((i, a)),
            "token1": b, "symbol1": meta.get(b, {}).get("symbol"), "decimals1": meta.get(b, {}).get("decimals"),
            "balance1": bal_by.get((i, b)),
        })
    path = f"{label}_pairs.json"
    json.dump(out, open(path, "w"), indent=1)
    print(f"[{label}] wrote {path}", flush=True)
    return out


def read_lending():
    out = {"comptroller": HUCK_COMPTROLLER, "head": HEAD, "markets": []}
    oracle = dec_addr(R.call(HUCK_COMPTROLLER, SEL["oracle"]))
    out["oracle"] = oracle
    syms = R.batch_call([(m, SEL["symbol"]) for m in HUCK_MARKETS], chunk=40)
    unders = R.batch_call([(m, SEL["underlying"]) for m in HUCK_MARKETS], chunk=40)
    unders = [dec_addr(w) if w and w != "0x" else None for w in unders]
    meta = {}
    us = sorted({u for u in unders if u})
    usyms = R.batch_call([(u, SEL["symbol"]) for u in us], chunk=40)
    udecs = R.batch_call([(u, SEL["decimals"]) for u in us], chunk=40)
    for i, u in enumerate(us):
        meta[u] = {"symbol": dec_str(usyms[i]), "decimals": dec_uint(udecs[i])}
    # market stats
    cash = R.batch_call([(m, SEL["getCash"]) for m in HUCK_MARKETS], chunk=40)
    borr = R.batch_call([(m, SEL["totalBorrows"]) for m in HUCK_MARKETS], chunk=40)
    resv = R.batch_call([(m, SEL["totalReserves"]) for m in HUCK_MARKETS], chunk=40)
    xrate = R.batch_call([(m, SEL["exchangeRateStored"]) for m in HUCK_MARKETS], chunk=40)
    tsup = R.batch_call([(m, SEL["totalSupply"]) for m in HUCK_MARKETS], chunk=40)
    prices = None
    if oracle:
        prices = R.batch_call([(oracle, enc_addr(SEL["getUnderlyingPrice"], m)) for m in HUCK_MARKETS], chunk=40)
    for i, m in enumerate(HUCK_MARKETS):
        u = unders[i]
        out["markets"].append({
            "market": m, "symbol": dec_str(syms[i]),
            "underlying": u,
            "underlying_symbol": meta.get(u, {}).get("symbol") if u else "MOVR(native)",
            "underlying_decimals": meta.get(u, {}).get("decimals") if u else 18,
            "getCash": dec_uint(cash[i]),
            "totalBorrows": dec_uint(borr[i]),
            "totalReserves": dec_uint(resv[i]),
            "exchangeRateStored": dec_uint(xrate[i]),
            "totalSupply": dec_uint(tsup[i]),
            "oracle_price_raw": dec_uint(prices[i]) if prices else None,
        })
    json.dump(out, open("huckleberry_lending.json", "w"), indent=1)
    print("[lending] wrote huckleberry_lending.json", flush=True)
    return out


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "moonswap"):
        enumerate_dex(MOONSWAP_FACTORY, "moonswap")
    if which in ("all", "huckamm"):
        enumerate_dex(HUCK_FACTORY, "huckleberry_amm")
    if which in ("all", "lending"):
        read_lending()
