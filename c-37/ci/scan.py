#!/usr/bin/env python3
"""C-37 heavy scan: empty-market donation-attack preconditions in Compound-v2 forks
(Rari Fuse on Ethereum + dForce Lending iTokens). Read-only JSON-RPC.

For every pool/market we record:
  totalSupply, cash, totalBorrows, underlying, isListed, collateralFactor,
  mint/borrow pause flags, oracle price, supply/borrow capacities.
A market is flagged CANDIDATE when it is EMPTY (totalSupply == 0) but still
listed with a nonzero collateral factor, minting allowed, and a nonzero oracle
price.  For each candidate we also report the same pool's other markets' cash
(the value an attacker could borrow and leave as bad debt).

Outputs: ci-out/fuse_scan.json, ci-out/dforce_scan.json, ci-out/summary.txt
"""
import json, sys, urllib.request, time, concurrent.futures as cf, os

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"
OUT = "ci-out"
os.makedirs(OUT, exist_ok=True)
_id = [0]

def rpc(method, params):
    _id[0] += 1
    req = {"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params}
    for attempt in range(4):
        try:
            with urllib.request.urlopen(
                urllib.request.Request(RPC, json.dumps(req).encode(),
                                       {"Content-Type": "application/json",
                                        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-ci/1.0"}),
                timeout=25) as r:
                j = json.load(r)
            if "result" in j:
                return j["result"]
        except Exception:
            time.sleep(0.3 * (attempt + 1))
    return None

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def u256(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return int(hexstr, 16)

def addr_arg(a):
    return "0" * 24 + a[2:].lower()

def sel(sig):
    # keccak selector via eth_call-free: hardcode known selectors
    return SELECTORS[sig]

SELECTORS = {
    "getAllMarkets()": "0xb0772d0b",
    "getAlliTokens()": "0x60a8a931",
    "markets(address)": "0x8e8f294b",
    "marketsV2(address)": "0x1221ec16",
    "mintGuardianPaused(address)": "0x731f0c2b",
    "borrowGuardianPaused(address)": "0x6d154ea5",
    "oracle()": "0x7dc0d1d0",
    "priceOracle()": "0x2630c12f",
    "getUnderlyingPrice(address)": "0xfc57d4df",
    "totalSupply()": "0x18160ddd",
    "getCash()": "0x3b1d21a2",
    "totalBorrows()": "0x47bd3718",
    "underlying()": "0x6f307dc3",
    "symbol()": "0x95d89b41",
    "comptroller()": "0x5fe3b567",
    "decimals()": "0x313ce567",
}

def dec_str(hexstr):
    if not hexstr or len(hexstr) < 130:
        return "?"
    try:
        b = bytes.fromhex(hexstr[2:])
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode("utf-8", "replace")
    except Exception:
        return "?"

# ---------------- Fuse ----------------
def fuse_pool(pool):
    comp = pool["comptroller"]
    res = {"name": pool["name"], "comptroller": comp, "markets": [], "error": None}
    r = call(comp, SELECTORS["getAllMarkets()"])
    if not r or len(r) < 130:
        res["error"] = "getAllMarkets failed"
        return res
    b = bytes.fromhex(r[2:])
    off = int.from_bytes(b[0:32], "big")
    n = int.from_bytes(b[off:off + 32], "big")
    markets = []
    for i in range(n):
        a = "0x" + b[off + 32 + i * 32: off + 64 + i * 32].hex()[-40:]
        markets.append(a)
    for m in markets:
        md = {"market": m}
        ts = call(m, SELECTORS["totalSupply()"])
        cash = call(m, SELECTORS["getCash()"])
        bor = call(m, SELECTORS["totalBorrows()"])
        und = call(m, SELECTORS["underlying()"])
        sym = call(m, SELECTORS["symbol()"])
        mk = call(comp, SELECTORS["markets(address)"] + addr_arg(m))
        mintp = call(comp, SELECTORS["mintGuardianPaused(address)"] + addr_arg(m))
        borrowp = call(comp, SELECTORS["borrowGuardianPaused(address)"] + addr_arg(m))
        md["totalSupply"] = u256(ts)
        md["cash"] = u256(cash)
        md["totalBorrows"] = u256(bor)
        md["underlying"] = ("0x" + und[-40:]) if und and len(und) >= 42 else None
        md["symbol"] = dec_str(sym)
        if mk and len(mk) >= 194:
            words = [mk[2 + i * 64: 2 + (i + 1) * 64] for i in range(len(mk[2:]) // 64)]
            md["isListed"] = int(words[0], 16) != 0
            md["collateralFactor"] = int(words[1], 16)
            md["isMinted"] = int(words[2], 16) != 0
        md["mintPaused"] = (u256(mintp) or 0) != 0
        md["borrowPaused"] = (u256(borrowp) or 0) != 0
        res["markets"].append(md)
    return res

# ---------------- dForce ----------------
def dforce_market(itoken, controller):
    md = {"market": itoken}
    ts = call(itoken, SELECTORS["totalSupply()"])
    cash = call(itoken, SELECTORS["getCash()"])
    bor = call(itoken, SELECTORS["totalBorrows()"])
    und = call(itoken, SELECTORS["underlying()"])
    sym = call(itoken, SELECTORS["symbol()"])
    md.update(totalSupply=u256(ts), cash=u256(cash), totalBorrows=u256(bor),
              underlying=("0x" + und[-40:]) if und and len(und) >= 42 else None,
              symbol=dec_str(sym))
    mv = call(controller, SELECTORS["marketsV2(address)"] + addr_arg(itoken))
    if mv and len(mv) >= 2 + 64 * 11:
        w = [mv[2 + i * 64: 2 + (i + 1) * 64] for i in range(11)]
        md.update(collateralFactor=int(w[0], 16), borrowFactor=int(w[1], 16),
                  borrowCapacity=int(w[2], 16), supplyCapacity=int(w[3], 16),
                  mintPaused=int(w[4], 16) != 0, redeemPaused=int(w[5], 16) != 0,
                  borrowPaused=int(w[6], 16) != 0)
    return md

def main():
    summary = []
    # --- Fuse ---
    pools = json.load(open("analysis/fuse_pools.json"))
    print(f"[fuse] scanning {len(pools)} pools ...", flush=True)
    fuse_out = []
    with cf.ThreadPoolExecutor(max_workers=12) as ex:
        for i, p in enumerate(ex.map(fuse_pool, pools)):
            fuse_out.append(p)
            if i % 25 == 0:
                print(f"[fuse] {i}/{len(pools)}", flush=True)
    json.dump(fuse_out, open(f"{OUT}/fuse_scan.json", "w"))
    cands = []
    for p in fuse_out:
        pool_cash = sum(m.get("cash") or 0 for m in p["markets"])
        for m in p["markets"]:
            ts = m.get("totalSupply")
            if ts == 0 and m.get("isListed") and (m.get("collateralFactor") or 0) > 0 \
               and not m.get("mintPaused") and not m.get("borrowPaused"):
                others = pool_cash - (m.get("cash") or 0)
                cands.append({"pool": p["name"], "comptroller": p["comptroller"],
                              "market": m["market"], "symbol": m.get("symbol"),
                              "cf": m.get("collateralFactor"), "pool_other_cash": others,
                              "underlying": m.get("underlying")})
    print(f"[fuse] empty-market candidates: {len(cands)}", flush=True)
    for c in cands:
        print(f"[fuse] CAND {c['pool']} {c['symbol']} cf={c['cf']} other_cash={c['pool_other_cash']}", flush=True)
    summary.append(f"fuse pools={len(pools)} empty_market_candidates={len(cands)}")
    json.dump(cands, open(f"{OUT}/fuse_candidates.json", "w"), indent=1)

    # --- dForce ---
    controller = "0x8B53Ab2c0Df3230EA327017C91Eb909f815Ad113"
    r = call(controller, SELECTORS["getAlliTokens()"])
    itokens = []
    if r and len(r) > 130:
        b = bytes.fromhex(r[2:])
        off = int.from_bytes(b[0:32], "big")
        n = int.from_bytes(b[off:off + 32], "big")
        for i in range(n):
            itokens.append("0x" + b[off + 32 + i * 32: off + 64 + i * 32].hex()[-40:])
    print(f"[dforce] scanning {len(itokens)} iTokens ...", flush=True)
    dm = []
    with cf.ThreadPoolExecutor(max_workers=8) as ex:
        for m in ex.map(lambda t: dforce_market(t, controller), itokens):
            dm.append(m)
    # oracle prices
    oracle = call(controller, SELECTORS["priceOracle()"])
    oracle = ("0x" + oracle[-40:]) if oracle and len(oracle) >= 42 else None
    for m in dm:
        if oracle:
            pr = call(oracle, SELECTORS["getUnderlyingPrice(address)"] + addr_arg(m["market"]))
            m["oraclePrice"] = u256(pr)
    json.dump({"controller": controller, "oracle": oracle, "markets": dm},
              open(f"{OUT}/dforce_scan.json", "w"))
    dcands = []
    cash_other = sum(m.get("cash") or 0 for m in dm)
    for m in dm:
        if m.get("totalSupply") == 0 and (m.get("collateralFactor") or 0) > 0 \
           and not m.get("mintPaused") and (m.get("supplyCapacity") or 0) > 0 \
           and (m.get("oraclePrice") or 0) > 0:
            dcands.append({**m, "pool_other_cash": cash_other - (m.get("cash") or 0)})
    print(f"[dforce] empty-market candidates: {len(dcands)}", flush=True)
    for c in dcands:
        print(f"[dforce] CAND {c['symbol']} cf={c['collateralFactor']} supplyCap={c['supplyCapacity']} price={c['oraclePrice']}", flush=True)
    summary.append(f"dforce itokens={len(itokens)} empty_market_candidates={len(dcands)}")
    json.dump(dcands, open(f"{OUT}/dforce_candidates.json", "w"), indent=1)

    with open(f"{OUT}/summary.txt", "w") as f:
        f.write("\n".join(summary) + "\n")
    print("[scan] summary: " + " | ".join(summary), flush=True)

if __name__ == "__main__":
    main()
