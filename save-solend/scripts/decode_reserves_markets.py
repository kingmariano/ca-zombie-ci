#!/usr/bin/env python3
"""Fetch + decode Solend deployed layout (commit d04ce00b, July 2025) and export analysis tables.

Read-only; public RPC only; no keys. Outputs to /home/heisenberg/CA/save-solend/analysis/.
"""
import json, base64, time, urllib.request, collections, os

RPC = "https://api.mainnet-beta.solana.com"
PROGRAM = "So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo"
OUT = "/home/heisenberg/CA/save-solend/analysis"
os.makedirs(OUT, exist_ok=True)

ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58(b: bytes) -> str:
    n = int.from_bytes(b, "big"); s = ""
    while n: n, r = divmod(n, 58); s = ALPH[r] + s
    return "1" * (len(b) - len(b.lstrip(b"\0"))) + (s or "")

def u(b, o, n): return int.from_bytes(b[o:o+n], "little")
def si(b, o, n): return int.from_bytes(b[o:o+n], "little", signed=True)
def pk(b, o): return b58(b[o:o+32])

def rpc(method, params, retries=8):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    delay = 1.0
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                out = json.load(r)
            if "error" in out: raise RuntimeError(str(out["error"])[:300])
            return out["result"]
        except Exception:
            if i == retries - 1: raise
            time.sleep(delay); delay *= 1.7

def chunk(l, n):
    for i in range(0, len(l), n): yield l[i:i+n]

def get_multi(keys):
    vals = []
    for batch in chunk(keys, 100):
        r = rpc("getMultipleAccounts", [batch, {"encoding": "base64", "commitment": "confirmed"}])
        for a, acc in zip(batch, r["value"]):
            vals.append((a, None if acc is None else base64.b64decode(acc["data"][0]), None if acc is None else acc["owner"]))
    return vals

def dec_reserve(b):
    if len(b) != 619: return {"err": "len", "len": len(b)}
    r = {}
    r["version"] = b[0]
    r["lastUpdate"] = {"slot": u(b,1,8), "stale": b[9] != 0}
    r["lendingMarket"] = pk(b,10)
    r["mint"] = pk(b,42); r["mintDecimals"] = b[74]; r["supply"] = pk(b,75)
    r["pythOracle"] = pk(b,107); r["switchboardOracle"] = pk(b,139)
    r["availableAmount"] = u(b,171,8)
    r["borrowedAmountWads"] = u(b,179,16)
    r["cumulativeBorrowRateWads"] = u(b,195,16)
    r["marketPrice"] = u(b,211,16)
    r["collateralMint"] = pk(b,227); r["collateralMintTotalSupply"] = u(b,259,8); r["collateralSupply"] = pk(b,267)
    c = {}
    c["optimalUtilizationRate"] = b[299]; c["loanToValueRatio"] = b[300]
    c["liquidationBonus"] = b[301]; c["liquidationThreshold"] = b[302]
    c["minBorrowRate"] = b[303]; c["optimalBorrowRate"] = b[304]; c["maxBorrowRate"] = b[305]
    c["borrowFeeWad"] = u(b,306,8); c["flashLoanFeeWad"] = u(b,314,8); c["hostFeePercentage"] = b[322]
    c["depositLimit"] = u(b,323,8); c["borrowLimit"] = u(b,331,8); c["feeReceiver"] = pk(b,339)
    c["protocolLiquidationFee"] = b[371]; c["protocolTakeRate"] = b[372]
    c["accumulatedProtocolFeesWads"] = u(b,373,16)
    rl = b[389:445]
    c["rateLimiter"] = {"windowDuration": u(rl,0,8), "maxOutflow": u(rl,8,8), "prevQty": u(rl,16,16), "windowStart": u(rl,32,8), "curQty": u(rl,40,16)}
    c["addedBorrowWeightBps"] = u(b,445,8)
    r["smoothedMarketPrice"] = u(b,453,16)
    c["reserveType"] = b[469]; c["maxUtilizationRate"] = b[470]; c["superMaxBorrowRate"] = u(b,471,8)
    c["maxLiquidationBonus"] = b[479]; c["maxLiquidationThreshold"] = b[480]
    c["scaledPriceOffsetBps"] = si(b,481,8)
    c["extraOraclePubkey"] = pk(b,489)
    r["extraMarketPrice"] = u(b,522,16) if b[521] else None
    c["attributedBorrowValue"] = u(b,538,16)
    c["attributedBorrowLimitOpen"] = u(b,554,8); c["attributedBorrowLimitClose"] = u(b,562,8)
    r["config"] = c
    return r

def dec_market(b):
    if len(b) != 290: return {"err": "len", "len": len(b)}
    rl = b[162:218]
    return {"version": b[0], "bumpSeed": b[1], "owner": pk(b,2), "quoteTokenMint": pk(b,34),
            "tokenProgramId": pk(b,66), "oracleProgramId": pk(b,98), "switchboardOracleProgramId": pk(b,130),
            "rateLimiter": {"windowDuration": u(rl,0,8), "maxOutflow": u(rl,8,8), "prevQty": u(rl,16,16), "windowStart": u(rl,32,8), "curQty": u(rl,40,16)},
            "whitelistedLiquidator": None if b[218:250] == b"\0"*32 else pk(b,218),
            "riskAuthority": pk(b,250)}

def main():
    cfgs = json.load(open("/tmp/opencode/solend_configs.json"))
    cfg_rows = {}
    for m in cfgs:
        for r in m["reserves"]:
            cfg_rows[r["address"]] = {"market": m["address"], "marketName": m["name"],
                                      "isPermissionless": m.get("isPermissionless"),
                                      "liquidityToken": r.get("liquidityToken"),
                                      "userBorrowCap": r.get("userBorrowCap"), "userSupplyCap": r.get("userSupplyCap")}
    mkt_addrs = [m["address"] for m in cfgs]
    res_addrs = list(cfg_rows.keys())

    mkt = {}
    for a, b, owner in get_multi(mkt_addrs):
        mkt[a] = {"owner": owner, "lamports": None, **(dec_market(b) if b else {"err":"missing"})}
    res = {}
    for a, b, owner in get_multi(res_addrs):
        res[a] = {"owner": owner, **(dec_reserve(b) if b else {"err":"missing"})}

    slot = rpc("getSlot", [{"commitment": "confirmed"}])
    bt = rpc("getBlockTime", [slot])
    out = {"slot": slot, "blockTime": bt, "fetchedAt": int(time.time()),
           "program": PROGRAM, "marketsRaw": mkt, "reservesRaw": res, "cfgRows": cfg_rows}
    json.dump(out, open("/tmp/opencode/solend_state_v2.json", "w"), indent=1)

    # ---- human tables ----
    def dec_wad(x): return x / 1e18
    rows = []
    for a, r in res.items():
        if "err" in r: continue
        cfg = r["config"]; meta = cfg_rows[a]
        tok = meta["liquidityToken"] or {}
        rows.append({
            "reserve": a, "market": r["lendingMarket"], "marketName": meta["marketName"],
            "permissionless": meta["isPermissionless"],
            "symbol": tok.get("symbol"), "mint": r["mint"], "decimals": r["mintDecimals"],
            "availableTokens": r["availableAmount"]/10**r["mintDecimals"],
            "borrowedTokens": dec_wad(r["borrowedAmountWads"])/10**r["mintDecimals"],
            "collateralSupply": r["collateralMintTotalSupply"]/10**r["mintDecimals"],
            "storedPriceUsd": dec_wad(r["marketPrice"]),
            "smoothedPriceUsd": dec_wad(r["smoothedMarketPrice"]),
            "extraPriceUsd": dec_wad(r["extraMarketPrice"]) if r["extraMarketPrice"] else None,
            "ltv": cfg["loanToValueRatio"], "liqThr": cfg["liquidationThreshold"], "liqBonus": cfg["liquidationBonus"],
            "maxLiqThr": cfg["maxLiquidationThreshold"], "maxLiqBonus": cfg["maxLiquidationBonus"],
            "reserveType": "Isolated" if cfg["reserveType"]==1 else "Regular",
            "depositLimit": cfg["depositLimit"], "borrowLimit": cfg["borrowLimit"],
            "borrowFeeWad": cfg["borrowFeeWad"], "flashFeeWad": cfg["flashLoanFeeWad"],
            "scaledPriceOffsetBps": cfg["scaledPriceOffsetBps"],
            "rateLimiter": cfg["rateLimiter"],
            "attributedOpen": cfg["attributedBorrowLimitOpen"], "attributedClose": cfg["attributedBorrowLimitClose"],
            "pythOracle": r["pythOracle"], "switchboardOracle": r["switchboardOracle"],
            "extraOracle": cfg["extraOraclePubkey"],
            "lastUpdate": r["lastUpdate"],
        })
    json.dump(rows, open(f"{OUT}/reserves.json", "w"), indent=1)

    mrows = []
    mres = collections.defaultdict(list)
    for a, r in res.items():
        if "err" not in r: mres[r["lendingMarket"]].append(a)
    for a, m in mkt.items():
        if "err" in m: continue
        mrows.append({"market": a, "name": next((c["name"] for c in cfgs if c["address"]==a), None),
                      "owner": m["owner"], "whitelistedLiquidator": m["whitelistedLiquidator"],
                      "rateLimiter": m["rateLimiter"], "reserves": len(mres.get(a, [])),
                      "reserveAddrs": mres.get(a, [])})
    json.dump(mrows, open(f"{OUT}/markets.json", "w"), indent=1)

    # oracle accounts
    orc = json.load(open("/tmp/opencode/solend_oracles.json"))
    omap = orc["oracles"]
    users = collections.defaultdict(lambda: {"roles": [], "reserves": []})
    for a, r in res.items():
        if "err" in r: continue
        for role, key in (("pyth", r["pythOracle"]), ("switchboard", r["switchboardOracle"]),
                          ("extra", r["config"]["extraOraclePubkey"])):
            if key and key != "11111111111111111111111111111111":
                users[key]["roles"].append(role); users[key]["reserves"].append(a)
    orows = {}
    for k, v in users.items():
        o = omap.get(k, {"exists": None})
        orows[k] = {"owner": o.get("owner"), "exists": o.get("exists"), "len": o.get("len"),
                    "pyth": o.get("pyth"), "roles": sorted(set(v["roles"])), "nReserves": len(set(v["reserves"])),
                    "sampleReserves": sorted(set(v["reserves"]))[:5]}
    json.dump(orows, open(f"{OUT}/oracle-accounts.json", "w"), indent=1)
    open(f"{OUT}/state-slot.txt", "w").write(f"slot={slot} blockTime={bt} fetchedAt={int(time.time())} program={PROGRAM}\n")

    # summary printout
    def val(r):
        return max(r["availableTokens"], r["borrowedTokens"])*r["storedPriceUsd"] if r["storedPriceUsd"] else 0
    per_market = collections.defaultdict(float)
    for r in rows: per_market[r["market"]] += val(r)
    print(f"slot={slot} reserves={len(rows)} markets={len(mrows)}")
    top = sorted(per_market.items(), key=lambda kv: -kv[1])[:25]
    name = {m["market"]: m["name"] for m in mrows}
    for a, v in top:
        n = len(mres[a])
        print(f"  {name.get(a,'?')[:34]:34s} {a[:8]}.. {n:3d} res  ${v/1e6:,.2f}M (stored-price)")
    print("whitelisted liquidators set:", sum(1 for m in mrows if m["whitelistedLiquidator"]))
    print("isolated-type reserves:", sum(1 for r in rows if r["reserveType"]=="Isolated"))

if __name__ == "__main__":
    main()
