#!/usr/bin/env python3
"""Arb step 5: exact max-profit computation per pool.
- Pool side: calculateSwap on the pool itself (grid bracketing + golden refinement, all live RPC).
- Market side: exact UniV2 getAmountIn/getAmountOut chains on current reserves.
Outputs: analysis/_profit.json  (plus later folded into markets.json)
"""
import json, urllib.request, os, time, math

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))

USD = 1.0001          # USDm
CELO_USD = 0.09416068042565741
MCUSD_USD = 1.0000883530085853   # llama mcUSD
MCUSD_B = 1.0          # mCUSD treated ~1:1 USD (Moola cUSD AToken)
EURM_USD = 1.1152041979847442

POOLS = {
    "P1_atUST":  "0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae",
    "P2_pUSD":   "0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c",
    "P3_pUSD2":  "0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735",
    "P4_pEUR":   "0x382ed834c6b7dbd10e4798b08889eaed1455e820",
    "P5_pEUR2":  "0x23c95678862a229fac088bd9705622d78130bc3e",
    "P6_pCELO":  "0x413ffcc28e6cdde7e93625ef4742810fe9738578",
    "P7_pCELO2": "0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a",
    "P8_USDCold":"0xcce0d62ce14fb3e4363eb92db37ff3630836c252",
    "P9_USDCet": "0xa5037661989789d0310ac2b796fa78f1b01f195d",
    "P10_aaUSDC":"0x0986b42f5f9c42feeef66fc23eba9ea1164c916d",
    "P11_BTC":   "0xaefc4e8cf655a182e8346b24c8abce45616ee0d2",
    "P12_BTC2":  "0x19260b9b573569ddb105780176547875fe9feda3",
}

# UniV2 pairs (address -> (token0, token1, r0, r1, dec0, dec1)) filled from _markets_raw.json
MARKETS = json.load(open(os.path.join(HERE, "_markets_raw.json")))["markets"]
UMETA = json.load(open(os.path.join(HERE, "_markets_raw.json")))["unknown_tokens"]
QDATA = json.load(open(os.path.join(HERE, "_quotes.json")))

TOK_DEC = dict(QDATA["tokens"])
# fill decimals for market tokens
for t, m in UMETA.items():
    TOK_DEC.setdefault(t, m)

BC = json.load(open(os.path.join(HERE, "_externals.json")))["blockscout"]


def pair(p):
    e = MARKETS[p]
    return e["token0"], e["token1"], int(e["reserve0"]), int(e["reserve1"])


def dec(t):
    d = TOK_DEC.get(t, {}).get("decimals")
    return d if d is not None else 18


# ---------- UniV2 math (0.3% fee) ----------
def amount_out(p, dx):
    t0, t1, r0, r1 = pair(p)
    return r1 * dx * 997 // (r0 * 1000 + dx * 997)


def amount_in(p, out):
    """how much of token0 to put in to get exactly `out` of token1"""
    t0, t1, r0, r1 = pair(p)
    if out >= r1:
        return None
    return (r0 * out * 1000) // (997 * (r1 - out)) + 1


def out_for_token(p, tok_in, dx):
    t0, t1, r0, r1 = pair(p)
    if tok_in == t0:
        return amount_out(p, dx)
    elif tok_in == t1:
        # swap roles
        if dx * 997 + r0 * 1000 == 0:
            return 0
        return r0 * dx * 997 // (r1 * 1000 + dx * 997)
    raise ValueError(f"token {tok_in} not in pair {p}")


def in_for_token(p, tok_out, out):
    t0, t1, r0, r1 = pair(p)
    if tok_out == t1:
        if out >= r1:
            return None
        return (r0 * out * 1000) // (997 * (r1 - out)) + 1
    elif tok_out == t0:
        if out >= r0:
            return None
        return (r1 * out * 1000) // (997 * (r0 - out)) + 1
    raise ValueError(f"token {tok_out} not in pair {p}")


# ---------- pool quotes via direct RPC ----------
def rpc_batch(calls, tries=6, batch=50):
    out = []
    for i in range(0, len(calls), batch):
        chunk = calls[i:i + batch]
        body = json.dumps([{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                           for j, (m, p) in enumerate(chunk)]).encode()
        last = None
        for t in range(tries):
            try:
                req = urllib.request.Request(RPC, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, dict):
                    raise RuntimeError(str(d)[:200])
                by_id = {it["id"]: it for it in d}
                out.extend((by_id.get(j) or {}).get("result") for j in range(len(chunk)))
                break
            except Exception as e:
                last = e
                time.sleep(1 + t)
        else:
            out.extend([None] * len(chunk))
    return out


def pool_quote(pool, i, j, dx):
    data = ("0xa95b089f" + hex(i)[2:].rjust(64, "0") + hex(j)[2:].rjust(64, "0")
            + hex(dx)[2:].rjust(64, "0"))
    r = rpc_batch([("eth_call", [{"to": pool, "data": data}, "latest"])])[0]
    if not r or r == "0x":
        return 0
    return int(r[2:66], 16)


def pool_quote_grid(pool, i, j, dxs):
    calls = [("eth_call", [{"to": pool, "data": "0xa95b089f" + hex(i)[2:].rjust(64, "0")
                            + hex(j)[2:].rjust(64, "0") + hex(int(dx))[2:].rjust(64, "0")}, "latest"])
             for dx in dxs]
    res = rpc_batch(calls)
    return {int(dx): (int(r[2:66], 16) if r and r != "0x" else 0) for dx, r in zip(dxs, res)}


def find_max_pool_out(pool, i, j, Lmax, revenue_usd_fn, cost_usd_fn, label, n_grid=26):
    """maximize profit(L)=revenue_usd_fn(poolOut(L)) - cost_usd_fn(L) over L in (0, Lmax]"""
    if Lmax <= 0:
        return None
    # log grid
    dxs = sorted({max(1, int(Lmax * (k / n_grid) ** 3)) for k in range(1, n_grid + 1)})
    q = pool_quote_grid(pool, i, j, dxs)
    rows = []
    for dx in dxs:
        out = q[dx]
        rev = revenue_usd_fn(out)
        cost = cost_usd_fn(dx)
        if rev is None or cost is None:
            continue
        rows.append((dx, out, cost, rev, rev - cost))
    if not rows:
        return None
    best = max(rows, key=lambda r: r[4])
    # golden refine around best dx (multiplicative bracket)
    lo = max(1, best[0] * 3 // 10)
    hi = min(Lmax, max(best[0] * 3, best[0] + 1))
    grid2 = [int(lo + (hi - lo) * k / 12) for k in range(1, 13)]
    q2 = pool_quote_grid(pool, i, j, [g for g in grid2 if g > 0 and g not in q])
    for dx in sorted(q2):
        out = q2[dx]
        rev = revenue_usd_fn(out)
        cost = cost_usd_fn(dx)
        if rev is None or cost is None:
            continue
        rows.append((dx, out, cost, rev, rev - cost))
    best = max(rows, key=lambda r: r[4])
    return {"pool": pool, "from_idx": i, "to_idx": j, "best_dx": best[0], "pool_out": best[1],
            "cost_usd": best[2], "revenue_usd": best[3], "profit_usd": best[4], "label": label,
            "all_points": [{"dx": r[0], "out": r[1], "cost_usd": r[2], "profit_usd": r[4]} for r in sorted(rows)]}


def main():
    res = {"block": None, "routes": {}, "assumptions": {
        "univ2_fee": "0.30% (997/1000)",
        "USDm_usd": USD, "CELO_usd": CELO_USD, "mcUSD_usd": MCUSD_USD, "mCUSD_usd": MCUSD_B,
        "EURm_usd": EURM_USD,
        "note": "mCUSD valued 1:1 USD conservatively; mcUSD at Llama 1.00009",
    }}
    res["block"] = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
    print("block", res["block"])

    pools = QDATA["pools"]
    usdm = "0x765de816845861e75a25fca122bb6898b8b1282a"
    celo = "0x471ece3750da237f93b8e339c536989b8978a438"

    # ---------- routes ----------
    # P1 atUST: buy with USDm on 0x752875e0
    P_ATUST = "0x752875e07e20bf03908d9f5d5c5e7dc330c801a1"

    def cost_P1(L):
        c = in_for_token(P_ATUST, "0xed193c4e69f591e42398ef54dea65aa1bb02835c", L)
        return None if c is None else c / 1e18 * USD
    r = find_max_pool_out(POOLS["P1_atUST"], 1, 0, 14_513_849_359_837_163_404_344, lambda o: o / 1e18 * USD, cost_P1, "atUST: buy on Ubeswap(USDm) -> sell to pool")
    res["routes"]["P1"] = r; print("P1", r and (r["best_dx"]/1e18, r["pool_out"]/1e18, r["profit_usd"]))

    # P2 pUSD_b4aa: buy with USDm on 0xec3741fb
    P_PUSD = "0xec3741fb21352af9251f5232b929a0c3150e577c"
    pUSD = "0xb4aa2986622249b1f45eb93f28cfca2b2606d809"

    def cost_P2(L):
        c = in_for_token(P_PUSD, pUSD, L)
        return None if c is None else c / 1e18 * USD
    r = find_max_pool_out(POOLS["P2_pUSD"], 1, 0, 614_029_653_824_799_441_101, lambda o: o / 1e18 * USD, cost_P2, "pUSD: buy on Ubeswap(USDm) -> sell to pool")
    res["routes"]["P2"] = r; print("P2", r and (r["best_dx"]/1e18, r["pool_out"]/1e18, r["profit_usd"]))

    # P3 pUSD_eadf: buy with MOBI on 0x7aef68d7; MOBI with USDm on 0x1eb738ec
    P_PUSD2 = "0x7aef68d7eb24f7ae09baf4d10e647b9ffebc6040"
    P_MOBI_USDM = "0x1eb738ec1d46c9befe95e830e19d0f537619f2d7"
    pUSD2 = "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226"
    mobi = "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b"

    def cost_P3(L):
        m = in_for_token(P_PUSD2, pUSD2, L)      # MOBI needed
        if m is None:
            return None
        u = in_for_token(P_MOBI_USDM, mobi, m)   # USDm needed
        if u is None:
            return None
        return u / 1e18 * USD
    r = find_max_pool_out(POOLS["P3_pUSD2"], 1, 0, 50_000_000, lambda o: o / 1e18 * USD, cost_P3, "pUSD2: buy with MOBI -> MOBI with USDm -> sell to pool")
    res["routes"]["P3"] = r; print("P3", r and (r["best_dx"]/1e18, r["pool_out"]/1e18, r["profit_usd"]))

    # P6 pCELO_e74a: (A) buy with POOF 0x993b0d1a, POOF with CELO 0x0931738d; (B) buy with CELO 0x3ea1e47f
    P_PC6_POOF = "0x993b0d1a2c7eff889f7e4ddc9a03b5085a2d1f27"
    P_POOF_CELO = "0x0931738d2c2998173058b635524e437172a6a96c"
    P_PC6_CELO = "0x3ea1e47f5126f6a6077a92965b9d1b1aa241893e"
    P_CELO_USDM = "0x1e593f1fe7b61c53874b54ec0c59fd0d5eb8621e"
    pc6 = "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1"
    poof = "0x00400fcbf0816bebb94654259de7273f4a05c762"

    def celo_to_usd(c):
        o = out_for_token(P_CELO_USDM, celo, int(c))
        return (o or 0) / 1e18 * USD

    def cost_P6A(L):
        pf = in_for_token(P_PC6_POOF, pc6, L)     # POOF needed
        if pf is None:
            return None
        c = in_for_token(P_POOF_CELO, poof, pf)   # CELO needed
        if c is None:
            return None
        return celo_to_usd(c)

    def rev_usd_celo(out):
        return out / 1e18 * USD  # CELO received; valued at Llama CELO price for revenue side first pass
    r = find_max_pool_out(POOLS["P6_pCELO"], 1, 0, 3_904_855_000_573_414_587_001, lambda o: o / 1e18 * CELO_USD, cost_P6A, "pCELO_e74a: buy with POOF(via CELO) -> sell to pool")
    res["routes"]["P6A"] = r; print("P6A", r and (r["best_dx"]/1e18, r["pool_out"]/1e18, r["profit_usd"]))

    def cost_P6B(L):
        c = in_for_token(P_PC6_CELO, pc6, L)      # CELO needed
        if c is None:
            return None
        return celo_to_usd(c)
    r = find_max_pool_out(POOLS["P6_pCELO"], 1, 0, 90_000_000_000_000_000, lambda o: o / 1e18 * CELO_USD, cost_P6B, "pCELO_e74a: buy with CELO -> sell to pool")
    res["routes"]["P6B"] = r; print("P6B", r and (r["best_dx"]/1e18, r["pool_out"]/1e18, r["profit_usd"]))

    # P7 pCELO_301a: buy with POOF 0xbdfc2268
    P_PC7_POOF = "0xbdfc22680b72f0b127d70988feb4b1a68c0b99eb"
    pc7 = "0x301a61d01a63c8d670c2b8a43f37d12ef181f997"

    def cost_P7(L):
        pf = in_for_token(P_PC7_POOF, pc7, L)
        if pf is None:
            return None
        c = in_for_token(P_POOF_CELO, poof, pf)
        if c is None:
            return None
        return celo_to_usd(c)
    r = find_max_pool_out(POOLS["P7_pCELO2"], 1, 0, 8_366_474_025_226_096_363_606, lambda o: o / 1e18 * CELO_USD, cost_P7, "pCELO_301a: buy with POOF(via CELO) -> sell to pool")
    res["routes"]["P7"] = r; print("P7", r and (r["best_dx"]/1e18, r["pool_out"]/1e18, r["profit_usd"]))

    # P8 USDC-old: buy with CELO 0xff4aa942, CELO bought with USDm on P_CELO_USDM
    P_USDCold_CELO = "0xff4aa942966297cc5dc3a5439af68fd9bd1fcc1f"
    usdcold = "0x1bfc26ce035c368503fae319cc2596716428ca44"

    def usdm_to_celo(c):
        # how much USDm to buy `c` CELO (c in CELO wei)
        t0, t1, r0, r1 = pair(P_CELO_USDM)
        if t0 == celo and t1 == usdm:
            if c >= r0:
                return None
            return (r1 * c * 1000) // (997 * (r0 - c)) + 1
        if t0 == usdm and t1 == celo:
            if c >= r1:
                return None
            return (r0 * c * 1000) // (997 * (r1 - c)) + 1
        raise ValueError("pair orientation")

    def cost_P8(L):
        c = in_for_token(P_USDCold_CELO, usdcold, L)   # CELO needed
        if c is None:
            return None
        u = usdm_to_celo(c)
        if u is None:
            return None
        return u / 1e18 * USD
    r = find_max_pool_out(POOLS["P8_USDCold"], 1, 0, 1_041_516_716, lambda o: o / 1e18 * USD, cost_P8, "USDCold: buy with CELO(via USDm) -> sell to pool")
    res["routes"]["P8"] = r; print("P8", r and (r["best_dx"]/1e6, r["pool_out"]/1e18, r["profit_usd"]))

    # P9 USDCet: buy with USDm 0xcd1d049a
    P_USDCET_USDM = "0xcd1d049abdff6d1781d419ca7a897c389f2440e5"
    usdcet = "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7"

    def cost_P9(L):
        c = in_for_token(P_USDCET_USDM, usdcet, L)
        return None if c is None else c / 1e18 * USD
    r = find_max_pool_out(POOLS["P9_USDCet"], 1, 0, 61_908_857_144, lambda o: o / 1e18 * USD, cost_P9, "USDCet: buy on Ubeswap(USDm) -> sell to pool")
    res["routes"]["P9"] = r; print("P9", r and (r["best_dx"]/1e6, r["pool_out"]/1e18, r["profit_usd"]))

    # ---- BTC pools ----
    d629 = "0xd629eb00deced2a080b7ec630ef6ac117e614f1b"
    baab = "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b"
    be50 = "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace"
    P_MCUSD_BAAB = "0x0448e99ab5f8230713a9f5d7e64ec2ab6e5952a3"
    P_MCUSD_BE50 = "0x724ff4aafa4fd2c44a1726707c2f1b3d1650eab9"
    P_MCUSD_D629 = "0x83cf02f79be87a7402a3cac013d0e1c95fefcaba"
    P_MCUSD_USDM = "0x4857e2f4e0b68bd31149f3f44ce0d883b7c4e440"

    # P11A: acquire baab with mcUSD (mcUSD=USDmc), sell to pool for d629, sell d629 for mCUSD (mCUSD~$1)
    def cost_P11A_usd(L):
        m = in_for_token(P_MCUSD_BAAB, baab, L)     # mcUSD needed
        if m is None:
            return None
        # value mcUSD in USD
        return m / 1e18 * MCUSD_USD

    def rev_P11A_usd(out_d629):
        # sell d629 to mCUSD pair
        o = out_for_token(P_MCUSD_D629, d629, out_d629)
        if o is None:
            return None
        return o / 1e18 * MCUSD_B
    r = find_max_pool_out(POOLS["P11_BTC"], 1, 0, 2_509_122, lambda o: rev_P11A_usd(o) or 0, cost_P11A_usd, "baab: buy with mcUSD -> pool -> sell d629 for mCUSD")
    res["routes"]["P11A"] = r; print("P11A", r and (r["best_dx"]/1e8, r["pool_out"]/1e18, r["profit_usd"]))

    # P11B: acquire d629 with mCUSD, sell to pool for baab, sell baab for mcUSD
    def cost_P11B_usd(L):
        m = in_for_token(P_MCUSD_D629, d629, L)   # mCUSD needed
        if m is None:
            return None
        return m / 1e18 * MCUSD_B

    def rev_P11B_usd(out_baab):
        o = out_for_token(P_MCUSD_BAAB, baab, out_baab)   # sell baab -> mcUSD
        if o is None:
            return None
        return o / 1e18 * MCUSD_USD
    r = find_max_pool_out(POOLS["P11_BTC"], 0, 1, 444_837_086_244_061_605, lambda o: rev_P11B_usd(o) or 0, cost_P11B_usd, "d629: buy with mCUSD -> pool -> sell baab for mcUSD")
    res["routes"]["P11B"] = r; print("P11B", r and (r["best_dx"]/1e18, r["pool_out"]/1e8, r["profit_usd"]))

    # P12A: acquire be50 with mcUSD, sell to pool for d629, sell d629 for mCUSD
    def cost_P12A_usd(L):
        m = in_for_token(P_MCUSD_BE50, be50, L)
        if m is None:
            return None
        return m / 1e18 * MCUSD_USD
    r = find_max_pool_out(POOLS["P12_BTC2"], 1, 0, 4_215_999, lambda o: rev_P11A_usd(o) or 0, cost_P12A_usd, "be50: buy with mcUSD -> pool -> sell d629 for mCUSD")
    res["routes"]["P12A"] = r; print("P12A", r and (r["best_dx"]/1e8, r["pool_out"]/1e18, r["profit_usd"]))

    # P12B: acquire d629 with mCUSD, sell to pool for be50, sell be50 for mcUSD
    def cost_P12B_usd(L):
        m = in_for_token(P_MCUSD_D629, d629, L)
        if m is None:
            return None
        return m / 1e18 * MCUSD_B

    def rev_P12B_usd(out_be50):
        o = out_for_token(P_MCUSD_BE50, be50, out_be50)
        if o is None:
            return None
        return o / 1e18 * MCUSD_USD
    r = find_max_pool_out(POOLS["P12_BTC2"], 0, 1, 965_776_110_786_401_503, lambda o: rev_P12B_usd(o) or 0, cost_P12B_usd, "d629: buy with mCUSD -> pool -> sell be50 for mcUSD")
    res["routes"]["P12B"] = r; print("P12B", r and (r["best_dx"]/1e18, r["pool_out"]/1e8, r["profit_usd"]))

    # ---------- marginal prices (small dx) for reporting ----------
    marg = {}
    eps = {
        "P1": (1, 0, 10**15), "P2": (1, 0, 10**15), "P3": (1, 0, 10**15), "P4": (1, 0, 10**15),
        "P5": (1, 0, 10**15), "P6": (1, 0, 10**15), "P7": (1, 0, 10**15), "P8": (1, 0, 1000),
        "P9": (1, 0, 1000), "P10": (1, 0, 10**15), "P11": (1, 0, 10**6), "P12": (1, 0, 10**6),
    }
    POOLKEY = {"P1": "P1_atUST", "P2": "P2_pUSD", "P3": "P3_pUSD2", "P4": "P4_pEUR", "P5": "P5_pEUR2",
               "P6": "P6_pCELO", "P7": "P7_pCELO2", "P8": "P8_USDCold", "P9": "P9_USDCet",
               "P10": "P10_aaUSDC", "P11": "P11_BTC", "P12": "P12_BTC2"}
    calls, keys = [], []
    for pname, pool in POOLS.items():
        short = [k for k, v in POOLKEY.items() if v == pname][0]
        i, j, dx = eps[short]
        calls.append(("eth_call", [{"to": pool, "data": "0xa95b089f" + hex(i)[2:].rjust(64, "0") + hex(j)[2:].rjust(64, "0") + hex(dx)[2:].rjust(64, "0")}, "latest"]))
        keys.append((short, "j2g"))
        calls.append(("eth_call", [{"to": pool, "data": "0xa95b089f" + hex(j)[2:].rjust(64, "0") + hex(i)[2:].rjust(64, "0") + hex(dx)[2:].rjust(64, "0")}, "latest"]))
        keys.append((short, "g2j"))
    resq = rpc_batch(calls)
    for (pname, k), r in zip(keys, resq):
        marg.setdefault(pname, {})[k] = int(r[2:66], 16) if r and r != "0x" else None
    res["marginal_eps"] = {"eps": eps, "raw": marg}
    print("done")

    with open(os.path.join(HERE, "_profit.json"), "w") as f:
        json.dump(res, f, indent=1)
    print("wrote _profit.json")


if __name__ == "__main__":
    main()
