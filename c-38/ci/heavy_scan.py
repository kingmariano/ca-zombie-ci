#!/usr/bin/env python3
"""C-38 heavy CI scan: Tectonic (Cronos) live state + exact extractable liquidation profit.

Read-only. Writes JSON results to ci-out/.
RPC: CRONOS_RPC_URL env (fallback https://cronos-evm-rpc.publicnode.com).
"""
import concurrent.futures as cf
import json
import os
import time
import urllib.request

RPC = os.environ.get("CRONOS_RPC_URL") or "https://cronos-evm-rpc.publicnode.com"
RPC_FALLBACK = "https://cronos-evm-rpc.publicnode.com"
SG = "https://graph-v2.cronoslabs.com/subgraphs/name/tectonic/tectonic-main"

UNITROLLER = "0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0"
ORACLE = "0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A"
TUSDC = "0xB3bbf1bE947b245Aef26e3B6a9D777d7703F4c8e"
TTONIC = "0xfe6934FDf050854749945921fAA83191Bccf20Ad"
VVS_USDC_TONIC_POOL = "0x2f12d47fe49b907d7a5df8159c1ce665187f15c4"
PROTO_SEIZE_SHARE = 0.028
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ci-out")
os.makedirs(OUT, exist_ok=True)

SEL = {
    "getAllMarkets": "0xb0772d0b", "oracle": "0x7dc0d1d0", "closeFactor": "0xe8755446",
    "liqIncentive": "0x4ada90af", "pauseGuardian": "0x24a3d622", "admin": "0xf851a440",
    "transferGuardianPaused": "0x87f76303", "seizeGuardianPaused": "0xac0b0bb7",
    "symbol": "0x95d89b41", "underlying": "0x6f307dc3", "tectonicCore": "0xc16a61ec",
    "totalSupply": "0x18160ddd", "totalBorrows": "0x47bd3718", "totalReserves": "0x8f840ddd",
    "getCash": "0x3b1d21a2", "exchangeRateStored": "0x182df0f5", "accrualBlockNumber": "0x6c540baf",
    "reserveFactorMantissa": "0x173b9904", "interestRateModel": "0xf3fdb15a", "decimals": "0x313ce567",
    "markets": "0x8e8f294b", "mintGuardianPaused": "0x731f0c2b", "borrowGuardianPaused": "0x6d154ea5",
    "borrowCaps": "0x4a584432", "supplyCaps": "0x02c3bcbb", "getUnderlyingPrice": "0xfc57d4df",
    "protocolSeizeShare": "0x6752e702", "getAccountSnapshot": "0xc37f68e2",
    "getAccountLiquidity": "0x5ec88c79", "mintAllowed": "0x4ef4c3e1", "borrowAllowed": "0xda3d454c",
    "redeemAllowed": "0xeabe7d91", "repayBorrowAllowed": "0x24008a62",
    "liquidateBorrowAllowed": "0x5fc7e71e", "seizeAllowed": "0xd02f7351", "transferAllowed": "0xbdcdc258",
    "getReserves": "0x0902f1ac", "token0": "0x0dfe1681", "token1": "0xd21220a7",
    "latestRoundData": "0xfeaf968c", "tTokenToOracle": "0x3a037039", "getExchangeRate": "0xe6aa216c",
}
TEST = "0x00000000000000000000000000000000DeaDBeef"

# Real (market) prices in USD - DefiLlama 2026-10-03. TONIC computed on-chain from VVS pool.
REAL_PRICES = {
    "USDC": 0.9999967, "USDT": 0.999918, "DAI": 0.99994, "TUSD": 0.99925, "USC": 1.0,
    "CRO": 0.06614218, "WBTC": 84592.60, "WETH": 2680.21, "VVS": 1.0769e-6,
    "XRP": 1.48327, "LTC": 68.6797, "ADA": 0.244304, "ATOM": 1.67090,
    "LCRO": 0.0844839, "CDCBTC": 84006.12, "CDCETH": 2868.70, "TONIC": 8.942e-9,
}


def rpc_call(url, method, params, timeout=45):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def eth_call(to, data, frm=None, block="latest"):
    obj = {"to": to, "data": data}
    if frm:
        obj["from"] = frm
    last = None
    for url in (RPC, RPC_FALLBACK):
        for _ in range(3):
            try:
                out = rpc_call(url, "eth_call", [obj, block])
                if "result" in out:
                    return out["result"]
                last = out.get("error")
            except Exception as e:
                last = str(e)
            time.sleep(0.4)
    return {"__error__": last}


def batch(calls, block="latest"):
    """calls: list of (to, data[, from]). Returns list of results."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i + 10]
        payload = []
        for j, c in enumerate(chunk):
            obj = {"to": c[0], "data": c[1]}
            if len(c) > 2 and c[2]:
                obj["from"] = c[2]
            payload.append({"jsonrpc": "2.0", "method": "eth_call", "params": [obj, block], "id": j})
        got = None
        body = json.dumps(payload).encode()
        for url in (RPC, RPC_FALLBACK):
            for _ in range(3):
                try:
                    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=90) as r:
                        got = json.loads(r.read())
                    break
                except Exception as e:
                    got = [{"error": str(e)}]
            if isinstance(got, list) and any("result" in x for x in got):
                break
            time.sleep(0.8)
        by_id = {x.get("id"): x for x in got} if isinstance(got, list) else {}
        for j in range(len(chunk)):
            it = by_id.get(j, {})
            out.append(it["result"] if "result" in it else {"__error__": it.get("error")})
        time.sleep(0.1)
    return out


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_uint(n):
    return hex(n)[2:].rjust(64, "0")


def dec_uint(h):
    if isinstance(h, dict) or not isinstance(h, str) or not h.startswith("0x") or len(h) < 3:
        return None
    return int(h, 16)


def dec_addr(h):
    if isinstance(h, dict) or not isinstance(h, str) or len(h) < 42:
        return None
    return "0x" + h[-40:]


def dec_str(h):
    if isinstance(h, dict) or not isinstance(h, str):
        return None
    try:
        b = bytes.fromhex(h[2:])
        ln = int.from_bytes(b[32:64], "big")
        return b[64:64 + ln].decode("utf-8", "replace")
    except Exception:
        return None


def gql(query, variables=None, retries=4):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(SG, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.loads(r.read())
            if "errors" in out:
                last = out["errors"]
                continue
            return out["data"]
        except Exception as e:
            last = str(e)
        time.sleep(1.0)
    raise RuntimeError(last)


def main():
    t0 = time.time()
    latest = rpc_call(RPC, "eth_blockNumber", [])["result"]
    blk = int(latest, 16)
    print(f"latest block: {blk}")

    # --- global ---
    g = batch([
        (UNITROLLER, SEL["getAllMarkets"]), (UNITROLLER, SEL["oracle"]), (UNITROLLER, SEL["closeFactor"]),
        (UNITROLLER, SEL["liqIncentive"]), (UNITROLLER, SEL["pauseGuardian"]), (UNITROLLER, SEL["admin"]),
        (UNITROLLER, SEL["transferGuardianPaused"]), (UNITROLLER, SEL["seizeGuardianPaused"]),
    ])
    markets = []
    mr = g[0]
    if isinstance(mr, str) and mr != "0x":
        b = bytes.fromhex(mr[2:])
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        for i in range(ln):
            markets.append("0x" + b[off + 32 + i * 32:off + 64 + i * 32][12:].hex())
    global_info = {
        "block": blk, "unitroller": UNITROLLER, "oracle": dec_addr(g[1]),
        "closeFactorMantissa": dec_uint(g[2]), "liquidationIncentiveMantissa": dec_uint(g[3]),
        "pauseGuardian": dec_addr(g[4]), "admin": dec_addr(g[5]),
        "transferGuardianPaused": dec_uint(g[6]), "seizeGuardianPaused": dec_uint(g[7]),
        "market_count": len(markets),
    }
    print(json.dumps(global_info, indent=1))

    # --- per market ---
    market_state = {}
    for m in markets:
        calls = [
            (m, SEL["symbol"]), (m, SEL["underlying"]), (m, SEL["tectonicCore"]), (m, SEL["totalSupply"]),
            (m, SEL["totalBorrows"]), (m, SEL["totalReserves"]), (m, SEL["getCash"]),
            (m, SEL["exchangeRateStored"]), (m, SEL["accrualBlockNumber"]), (m, SEL["reserveFactorMantissa"]),
            (m, SEL["interestRateModel"]), (m, SEL["decimals"]), (m, SEL["protocolSeizeShare"]),
            (UNITROLLER, SEL["markets"] + enc_addr(m)),
            (UNITROLLER, SEL["mintGuardianPaused"] + enc_addr(m)),
            (UNITROLLER, SEL["borrowGuardianPaused"] + enc_addr(m)),
            (UNITROLLER, SEL["borrowCaps"] + enc_addr(m)),
            (UNITROLLER, SEL["supplyCaps"] + enc_addr(m)),
            (ORACLE, SEL["getUnderlyingPrice"] + enc_addr(m)),
        ]
        r = batch(calls)
        d = {
            "symbol": dec_str(r[0]), "underlying": dec_addr(r[1]), "tectonicCore": dec_addr(r[2]),
            "totalSupply": dec_uint(r[3]), "totalBorrows": dec_uint(r[4]), "totalReserves": dec_uint(r[5]),
            "getCash": dec_uint(r[6]), "exchangeRateStored": dec_uint(r[7]), "accrualBlockNumber": dec_uint(r[8]),
            "reserveFactorMantissa": dec_uint(r[9]), "interestRateModel": dec_addr(r[10]),
            "decimals": dec_uint(r[11]), "protocolSeizeShareMantissa": dec_uint(r[12]),
            "mintGuardianPaused": dec_uint(r[14]), "borrowGuardianPaused": dec_uint(r[15]),
            "borrowCaps": dec_uint(r[16]), "supplyCaps": dec_uint(r[17]),
            "oraclePrice": dec_uint(r[18]),
        }
        mr = r[13]
        if isinstance(mr, str) and len(mr) >= 130:
            bb = bytes.fromhex(mr[2:])
            d["isListed"] = bool(int.from_bytes(bb[0:32], "big"))
            d["collateralFactorMantissa"] = int.from_bytes(bb[32:64], "big")
        # gates (from = market)
        gt = batch([
            (UNITROLLER, SEL["mintAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["borrowAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["redeemAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["repayBorrowAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["liquidateBorrowAllowed"] + enc_addr(m) + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["seizeAllowed"] + enc_addr(m) + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
            (UNITROLLER, SEL["transferAllowed"] + enc_addr(m) + enc_addr(TEST) + enc_addr(TEST) + enc_uint(1), m),
        ])
        d["gates"] = {
            "mintAllowed": gt[0] if isinstance(gt[0], dict) else dec_uint(gt[0]),
            "borrowAllowed": gt[1] if isinstance(gt[1], dict) else dec_uint(gt[1]),
            "redeemAllowed": gt[2] if isinstance(gt[2], dict) else dec_uint(gt[2]),
            "repayBorrowAllowed": gt[3] if isinstance(gt[3], dict) else dec_uint(gt[3]),
            "liquidateBorrowAllowed": gt[4] if isinstance(gt[4], dict) else dec_uint(gt[4]),
            "seizeAllowed": gt[5] if isinstance(gt[5], dict) else dec_uint(gt[5]),
            "transferAllowed": gt[6] if isinstance(gt[6], dict) else dec_uint(gt[6]),
        }
        market_state[m] = d
        print(f"{d['symbol']:10s} cash={d['getCash']} borrows={d['totalBorrows']} mintPaused={d['mintGuardianPaused']} borrowPaused={d['borrowGuardianPaused']}")
    json.dump({"global": global_info, "markets": market_state}, open(os.path.join(OUT, "market_state.json"), "w"), indent=1)

    # --- TONIC oracle vs DEX ---
    feed = dec_addr(eth_call(ORACLE, SEL["tTokenToOracle"] + enc_addr(TTONIC)))
    lrd = eth_call(feed, SEL["latestRoundData"])
    tonic_feed = None
    if isinstance(lrd, str) and len(lrd) >= 2 + 64 * 5:
        b = bytes.fromhex(lrd[2:])
        tonic_feed = {
            "feed": feed, "answer": int.from_bytes(b[32:64], "big", signed=True),
            "updatedAt": int.from_bytes(b[96:128], "big"),
        }
    pool = batch([(VVS_USDC_TONIC_POOL, SEL["getReserves"]), (VVS_USDC_TONIC_POOL, SEL["token0"]), (VVS_USDC_TONIC_POOL, SEL["token1"])])
    tonic_dex = None
    if all(isinstance(x, str) for x in pool[:1]):
        b = bytes.fromhex(pool[0][2:])
        r0 = int.from_bytes(b[0:32], "big")
        r1 = int.from_bytes(b[32:64], "big")
        # token0=USDC (6), token1=TONIC (18)
        tonic_dex = {"reserve0": r0, "reserve1": r1, "price_usd": (r0 / 1e6) / (r1 / 1e18) if r1 else None}
    tonic_check = {"feed": tonic_feed, "dex_pool": tonic_dex,
                   "oracle_usd": (tonic_feed["answer"] / 1e12) if tonic_feed else None,
                   "premium_x": ((tonic_feed["answer"] / 1e12) / tonic_dex["price_usd"]) if tonic_feed and tonic_dex and tonic_dex["price_usd"] else None}
    json.dump(tonic_check, open(os.path.join(OUT, "oracle_tonic.json"), "w"), indent=1)
    print("TONIC check:", json.dumps(tonic_check))
    if tonic_dex and tonic_dex.get("price_usd"):
        REAL_PRICES["TONIC"] = tonic_dex["price_usd"]

    # --- borrowers from subgraph ---
    borrowers = []
    skip = 0
    while True:
        q = """query($skip: Int!){ accountTTokens(first: 1000, skip: $skip, where: {storedBorrowBalance_gt: "0"}, orderBy: storedBorrowBalance, orderDirection: desc) {
          id storedBorrowBalance tTokenBalance account { id } market { id symbol underlyingSymbol } } }"""
        rows = gql(q, {"skip": skip})["accountTTokens"]
        borrowers.extend(rows)
        if len(rows) < 1000:
            break
        skip += 1000
    accts = sorted(set(x["account"]["id"].lower() for x in borrowers))
    print(f"borrower positions={len(borrowers)} accounts={len(accts)}")

    # --- shortfall scan ---
    def scan_chunk(chunk):
        calls = [(UNITROLLER, SEL["getAccountLiquidity"] + enc_addr(a)) for a in chunk]
        res = batch(calls)
        out = {}
        for a, r in zip(chunk, res):
            if isinstance(r, str) and len(r) >= 2 + 192:
                b = bytes.fromhex(r[2:])
                out[a] = {"liquidity": int.from_bytes(b[32:64], "big"), "shortfall": int.from_bytes(b[64:96], "big")}
            else:
                out[a] = {"error": r}
        return out

    chunks = [accts[i:i + 10] for i in range(0, len(accts), 10)]
    results = {}
    done = 0
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(scan_chunk, c) for c in chunks]
        for f in cf.as_completed(futs):
            results.update(f.result())
            done += 1
            if done % 100 == 0:
                print(f"  shortfall {done}/{len(chunks)}", flush=True)
    short = {a: r for a, r in results.items() if r.get("shortfall", 0) > 0}
    tot_short = sum(r["shortfall"] for r in short.values()) / 1e18
    print(f"shortfall accounts={len(short)} total_shortfall_usd={tot_short:.2f}")
    json.dump({"block": blk, "accounts_scanned": len(accts), "shortfall_accounts": len(short),
               "total_shortfall_usd": tot_short, "results": results},
              open(os.path.join(OUT, "shortfall_scan.json"), "w"), indent=1)

    # --- exact on-chain collateral/debt for shortfall accounts ---
    # positions per account from subgraph
    positions = {}
    alist = list(short.keys())
    for i in range(0, len(alist), 500):
        chunk = alist[i:i + 500]
        q = """query($ids:[String!]){ accountTTokens(first: 1000, where:{account_in:$ids}) {
          storedBorrowBalance tTokenBalance account{id} market{id symbol underlyingSymbol underlyingDecimals} } }"""
        for r in gql(q, {"ids": chunk})["accountTTokens"]:
            positions.setdefault(r["account"]["id"].lower(), []).append(r)

    # collect unique (market, account) pairs needing snapshots
    pairs = []
    for a, ps in positions.items():
        for p in ps:
            if float(p["tTokenBalance"]) > 0 or float(p["storedBorrowBalance"]) > 0:
                pairs.append((p["market"]["id"].lower(), a))
    print(f"snapshot pairs: {len(pairs)}")
    snap = {}
    pchunks = [pairs[i:i + 10] for i in range(0, len(pairs), 10)]
    done = 0

    def snap_chunk(chunk):
        calls = [(m, SEL["getAccountSnapshot"] + enc_addr(a)) for m, a in chunk]
        res = batch(calls)
        out = {}
        for (m, a), r in zip(chunk, res):
            if isinstance(r, str) and len(r) >= 2 + 256:
                b = bytes.fromhex(r[2:])
                out[(m, a)] = {
                    "cTokenBalance": int.from_bytes(b[32:64], "big"),
                    "borrowBalance": int.from_bytes(b[64:96], "big"),
                    "exchangeRate": int.from_bytes(b[96:128], "big"),
                }
            else:
                out[(m, a)] = None
        return out

    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(snap_chunk, c) for c in pchunks]
        for f in cf.as_completed(futs):
            snap.update(f.result())
            done += 1
            if done % 100 == 0:
                print(f"  snapshots {done}/{len(pchunks)}", flush=True)

    # price maps
    def price_usd(m, raw):
        if raw is None:
            return None
        dec = market_state[m]["decimals"] or 8
        # oracle price is scaled 1e(36-underlyingDecimals); derive USD
        # underlying decimals from subgraph market info or known mapping
        return raw / (10 ** (36 - dec))
    # use subgraph underlying decimals where available
    mdec = {}
    for m in market_state:
        mdec[m] = market_state[m]["decimals"]
    # Underlying decimals map from known Cronos tokens
    UNDERLYING_DEC = {
        "USDC": 6, "USDT": 6, "DAI": 18, "TUSD": 18, "USC": 18, "CRO": 18, "WBTC": 8,
        "WETH": 18, "TONIC": 18, "VVS": 18, "XRP": 6, "LTC": 8, "ADA": 6, "ATOM": 6,
        "LCRO": 18, "CDCBTC": 8, "CDCETH": 18,
    }
    extractable = []
    total_profit = 0.0
    for a, ps in positions.items():
        debts, cols = [], []
        for p in ps:
            m = p["market"]["id"].lower()
            if m not in market_state:
                continue
            sym = market_state[m]["symbol"]
            usym = p["market"]["underlyingSymbol"]
            udec = UNDERLYING_DEC.get(usym, 18)
            s = snap.get((m, a))
            if not s:
                continue
            op_raw = market_state[m]["oraclePrice"]
            if not op_raw:
                continue
            op_usd = op_raw / (10 ** (36 - udec))  # oracle USD per token
            # Compound math: underlying_raw = cToken_raw * exchangeRate_raw / 1e18
            under_raw = (s["cTokenBalance"] * s["exchangeRate"]) // (10 ** 18)
            under = under_raw / (10 ** udec)  # underlying tokens
            debt = s["borrowBalance"] / (10 ** udec)
            col_usd = under * op_usd
            debt_usd = debt * op_usd
            rr = REAL_PRICES.get(usym, 1.0) / op_usd if op_usd else 1.0
            if under > 0:
                cols.append({"market": sym, "usym": usym, "oracle_usd": col_usd, "real_ratio": rr})
            if debt > 0:
                debts.append({"market": sym, "usym": usym, "oracle_usd": debt_usd, "real_ratio": rr})
        best = None
        for dd in debts:
            for cc in cols:
                repay_oracle = min(0.5 * dd["oracle_usd"], cc["oracle_usd"] / 1.1)
                if repay_oracle <= 0:
                    continue
                profit = repay_oracle * 1.1 * (1 - PROTO_SEIZE_SHARE) * cc["real_ratio"] - repay_oracle * dd["real_ratio"]
                if best is None or profit > best["profit_usd"]:
                    best = {"debt": dd["market"], "coll": cc["market"], "repay_oracle_usd": repay_oracle,
                            "profit_usd": profit, "debt_oracle_usd": dd["oracle_usd"], "coll_oracle_usd": cc["oracle_usd"]}
        if best and best["profit_usd"] > 0:
            total_profit += best["profit_usd"]
            extractable.append({"account": a, **best})
    extractable.sort(key=lambda x: -x["profit_usd"])
    summary = {"block": blk, "accounts_with_positive_profit": len(extractable),
               "total_extractable_usd_best_pair_per_account": total_profit,
               "top50": extractable[:50]}
    json.dump(summary, open(os.path.join(OUT, "extractable.json"), "w"), indent=1)
    print(f"TOTAL EXTRACTABLE (liquidation, best pair per account): ${total_profit:,.2f} across {len(extractable)} accounts")
    for e in extractable[:10]:
        print(f"  {e['account']} {e['debt']}->{e['coll']} profit=${e['profit_usd']:.4f}")
    print(f"done in {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
