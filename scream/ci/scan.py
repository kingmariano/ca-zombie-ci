#!/usr/bin/env python3
"""Scream (Fantom) live-state scan — read-only. Writes results to ci-out/."""
import json, os, sys, time, urllib.request

CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
ORACLE = "0x0b24e9420c125242a5ec438bc65e48af1e866ddd"
SCLINK = "0x2359012ebe36cca231203d78b914284947b58aa3"
TOP_HOLDER = "0x91a88dd9c43e1e6d580abe4c54f1b6b53900a644"
LIQ_FUSD = "0x539654afe0c85df7db6176258f6dce567d2f8c13"

SEL = {
    "getAllMarkets()": "0xb0772d0b",
    "getCash()": "0x3b1d21a2",
    "totalSupply()": "0x18160ddd",
    "totalBorrows()": "0x47bd3718",
    "totalReserves()": "0x8f840ddd",
    "exchangeRateStored()": "0x182df0f5",
    "borrowIndex()": "0xaa5af0fd",
    "accrualBlockNumber()": "0x6c540baf",
    "reserveFactorMantissa()": "0x173b9904",
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "underlying()": "0x6f307dc3",
    "decimals()": "0x313ce567",
    "balanceOf(address)": "0x70a08231",
    "borrowBalanceCurrent(address)": "0x17bfdfbc",
    "markets(address)": "0x8e8f294b",
    "mintGuardianPaused(address)": "0x731f0c2b",
    "borrowGuardianPaused(address)": "0x6d154ea5",
    "getUnderlyingPrice(address)": "0xfc57d4df",
    "aggregators(address)": "0x112cdab9",
    "getAccountLiquidity(address)": "0x5ec88c79",
    "getAssetsIn(address)": "0xabfceffc",
    "closeFactorMantissa()": "0xe8755446",
    "liquidationIncentiveMantissa()": "0x4ada90af",
    "oracle()": "0x7dc0d1d0",
    "pauseGuardian()": "0x24a3d622",
    "admin()": "0xf851a440",
    "comptrollerImplementation()": "0xbb82aa5e",
    "transferGuardianPaused()": "0x87f76303",
    "seizeGuardianPaused()": "0xac0b0bb7",
}

PUBLIC = ["https://rpcapi.fantom.network", "https://fantom.api.onfinality.io/public",
          "https://fantom.drpc.org"]

def rpc_post(url, payload, timeout=40):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())

def pick_rpc():
    cands = []
    env = os.environ.get("FANTOM_RPC_URL", "")
    if env:
        cands.append(env)
    cands += PUBLIC
    for u in cands:
        try:
            r = rpc_post(u, {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})
            if "result" in r:
                return u
        except Exception:
            continue
    raise SystemExit("no working Fantom RPC")

RPC = [None]

def post(payload):
    for a in range(6):
        try:
            return rpc_post(RPC[0], payload)
        except Exception:
            if a == 5: raise
            time.sleep(1.0 + a)

def call(to, sig, arg=None):
    data = SEL[sig] + (arg[2:].lower().rjust(64, "0") if arg else "")
    r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]})
    return r.get("result", {"error": r.get("error")})

def fw(r):
    if isinstance(r, str) and len(r) >= 66:
        return int(r[2:66], 16)
    return None

def addr(r):
    v = fw(r)
    return "0x" + hex(v)[2:].rjust(40, "0") if v is not None else None

def dstr(r):
    if not isinstance(r, str) or r == "0x": return r
    b = bytes.fromhex(r[2:])
    try:
        off = int.from_bytes(b[:32], "big"); ln = int.from_bytes(b[off:off+32], "big")
        return b[off+32:off+32+ln].decode("utf-8", "replace")
    except Exception:
        return r

def decode_arr(r):
    if not isinstance(r, str) or len(r) < 130: return []
    b = r[2:]; off = int(b[:64], 16); ln = int(b[off*2:off*2+64], 16)
    return ["0x" + b[(off+32+i*32)*2+24:(off+32+i*32+32)*2] for i in range(ln)]

def main():
    out = {}
    RPC[0] = pick_rpc()
    print("RPC:", RPC[0])
    b1 = int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    time.sleep(3)
    b2 = int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    blk = post({"jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber", "params": ["latest", False]})["result"]
    out["chain"] = {"rpc": RPC[0], "chainId": int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_chainId", "params": []})["result"], 16),
                    "block_first": b1, "block_second": b2, "advancing": b2 > b1,
                    "latest_ts": int(blk["timestamp"], 16), "txs_in_latest_block": len(blk["transactions"])}

    mkts = decode_arr(call(CTRL, "getAllMarkets()"))
    out["comptroller"] = {
        "oracle": addr(call(CTRL, "oracle()")),
        "pauseGuardian": addr(call(CTRL, "pauseGuardian()")),
        "admin": addr(call(CTRL, "admin()")),
        "comptrollerImplementation": addr(call(CTRL, "comptrollerImplementation()")),
        "closeFactorMantissa": fw(call(CTRL, "closeFactorMantissa()")),
        "liquidationIncentiveMantissa": fw(call(CTRL, "liquidationIncentiveMantissa()")),
        "transferGuardianPaused": fw(call(CTRL, "transferGuardianPaused()")),
        "seizeGuardianPaused": fw(call(CTRL, "seizeGuardianPaused()")),
        "marketCount": len(mkts),
    }

    rows = []
    for a in mkts:
        m = {}
        for f in ["symbol()", "underlying()", "getCash()", "totalSupply()", "totalBorrows()",
                  "totalReserves()", "exchangeRateStored()", "borrowIndex()", "accrualBlockNumber()",
                  "reserveFactorMantissa()"]:
            m[f] = call(a, f)
        # comptroller-level reads keyed by market
        m["markets(address)"] = call(CTRL, "markets(address)", a)
        m["mintGuardianPaused(address)"] = call(CTRL, "mintGuardianPaused(address)", a)
        m["borrowGuardianPaused(address)"] = call(CTRL, "borrowGuardianPaused(address)", a)
        m["symbol"] = dstr(m["symbol()"])
        m["underlying"] = addr(m["underlying()"])
        dec = fw(call(m["underlying"], "decimals()")) if m["underlying"] else 18
        m["decimals"] = dec
        m["getCash"] = fw(m["getCash()"]); m["totalSupply"] = fw(m["totalSupply()"])
        m["totalBorrows"] = fw(m["totalBorrows()"]); m["totalReserves"] = fw(m["totalReserves()"])
        m["exchangeRateStored"] = fw(m["exchangeRateStored()"]); m["borrowIndex"] = fw(m["borrowIndex()"])
        m["accrualBlockNumber"] = fw(m["accrualBlockNumber()"]); m["reserveFactor"] = fw(m["reserveFactorMantissa()"])
        mk = m["markets(address)"]
        m["collateralFactor"] = int(mk[66:130], 16) if isinstance(mk, str) and len(mk) >= 194 else None
        m["isListed"] = int(mk[2:66], 16) if isinstance(mk, str) and len(mk) >= 194 else None
        m["mintPaused"] = fw(m["mintGuardianPaused(address)"])
        m["borrowPaused"] = fw(m["borrowGuardianPaused(address)"])
        m["underlyingBalance"] = fw(call(m["underlying"], "balanceOf(address)", a)) if m["underlying"] else None
        # oracle
        pr = call(ORACLE, "getUnderlyingPrice(address)", a)
        m["oraclePrice"] = fw(pr) if isinstance(pr, str) and len(pr) >= 66 else None
        m["oracleReverts"] = not isinstance(pr, str)
        agg = call(ORACLE, "aggregators(address)", a)
        m["aggregator"] = addr(agg) if isinstance(agg, str) else None
        m["market"] = a
        rows.append(m)

    out["markets"] = rows

    # liquidation candidate (the only one, discovered off-chain)
    liq = call(CTRL, "getAccountLiquidity(address)", LIQ_FUSD)
    if isinstance(liq, str) and len(liq) >= 194:
        out["liquidatable_account"] = {
            "address": LIQ_FUSD,
            "err": int(liq[2:66], 16), "liquidity": int(liq[66:130], 16), "shortfall": int(liq[130:194], 16),
            "assets": decode_arr(call(CTRL, "getAssetsIn(address)", LIQ_FUSD)),
            "debt_fusd": fw(call("0x83fad9bce24b605fe149b433d62c8011070239b8", "borrowBalanceCurrent(address)", LIQ_FUSD)),
        }
    else:
        out["liquidatable_account"] = {"address": LIQ_FUSD, "error": "reverted"}

    # top scLINK holder + prize
    out["sclink"] = {
        "market": SCLINK,
        "getCash": fw(call(SCLINK, "getCash()")),
        "totalSupply": fw(call(SCLINK, "totalSupply()")),
        "totalBorrows": fw(call(SCLINK, "totalBorrows()")),
        "exchangeRateStored": fw(call(SCLINK, "exchangeRateStored()")),
        "topHolder": TOP_HOLDER,
        "topHolderBalance": fw(call(SCLINK, "balanceOf(address)", TOP_HOLDER)),
    }

    # real prices from DefiLlama (best effort)
    try:
        unds = sorted({m["underlying"] for m in rows if m.get("underlying")})
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"fantom:{u}" for u in unds)
        pr = json.loads(urllib.request.urlopen(url, timeout=30).read()).get("coins", {})
    except Exception as e:
        pr = {}
        print("price fetch failed:", e)
    for m in rows:
        p = pr.get(f"fantom:{m['underlying']}", {}).get("price")
        m["realPrice"] = p
        if m["getCash"] is not None and p is not None and m.get("decimals"):
            m["cashUsd"] = m["getCash"] / 10 ** m["decimals"] * p
        else:
            m["cashUsd"] = None

    os.makedirs("ci-out", exist_ok=True)
    json.dump(out, open("ci-out/state.json", "w"), indent=2)

    with open("ci-out/market_table.txt", "w") as f:
        f.write(f"block={out['chain']['block_second']} chainId={out['chain']['chainId']} advancing={out['chain']['advancing']}\n")
        f.write(f"{'symbol':10} {'cash':>18} {'totalSupply':>18} {'borrows':>18} {'exRate':>22} {'accrBlk':>10} {'CF':>4} {'mintP':>5} {'borrP':>5} {'oracle':>22} {'aggregator':>44}\n")
        for m in rows:
            op = m["oraclePrice"] if m["oraclePrice"] is not None else "REVERT"
            f.write(f"{str(m['symbol']):10} {str(m['getCash']):>18} {str(m['totalSupply']):>18} {str(m['totalBorrows']):>18} {str(m['exchangeRateStored']):>22} {str(m['accrualBlockNumber']):>10} {str(m['collateralFactor']):>4} {str(m['mintPaused']):>5} {str(m['borrowPaused']):>5} {str(op):>22} {str(m['aggregator']):>44}\n")
        f.write(f"\nliquidatable_account={json.dumps(out['liquidatable_account'])}\n")
        f.write(f"sclink={json.dumps(out['sclink'])}\n")

    with open("ci-out/oracle_table.txt", "w") as f:
        f.write(f"oracle={out['comptroller']['oracle']}\n")
        f.write(f"{'symbol':10} {'oraclePrice':>24} {'realPrice':>14} {'cashUsd':>14} {'oracleReverts':>13} {'aggregator':>44}\n")
        for m in rows:
            f.write(f"{str(m['symbol']):10} {str(m['oraclePrice']):>24} {str(m['realPrice']):>14} {str(m['cashUsd']):>14} {str(m['oracleReverts']):>13} {str(m['aggregator']):>44}\n")

    summary = {
        "block": out["chain"]["block_second"], "chain_advancing": out["chain"]["advancing"],
        "markets": len(rows),
        "mint_paused_all": all(m["mintPaused"] == 1 for m in rows),
        "borrow_paused_all": all(m["borrowPaused"] == 1 for m in rows),
        "oracle_reverting_markets": [m["symbol"] for m in rows if m["oracleReverts"]],
        "cash_usd_total": sum(m["cashUsd"] or 0 for m in rows),
        "sclink_cash_link": (out["sclink"]["getCash"] or 0) / 1e18,
        "liquidatable_account": out["liquidatable_account"],
    }
    json.dump(summary, open("ci-out/summary.json", "w"), indent=2)
    print(json.dumps(summary, indent=2)[:3000])

if __name__ == "__main__":
    main()
