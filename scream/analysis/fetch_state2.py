#!/usr/bin/env python3
"""Rebuild full Scream state with first-word decoding. Read-only."""
import json, sys, time, urllib.request

RPC = "https://fantom.drpc.org"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
ORACLE = "0x0b24e9420c125242a5ec438bc65e48af1e866ddd"

SEL = {
    "symbol()": "0x95d89b41", "name()": "0x06fdde03", "decimals()": "0x313ce567",
    "balanceOf(address)": "0x70a08231", "underlying()": "0x6f307dc3", "getCash()": "0x3b1d21a2",
    "totalSupply()": "0x18160ddd", "totalBorrows()": "0x47bd3718", "totalReserves()": "0x8f840ddd",
    "exchangeRateStored()": "0x182df0f5", "accrualBlockNumber()": "0x6c540baf",
    "reserveFactorMantissa()": "0x173b9904", "borrowRatePerBlock()": "0xf8f9da28",
    "supplyRatePerBlock()": "0xae9d70b0", "interestRateModel()": "0xf3fdb15a",
    "comptroller()": "0x5fe3b567", "admin()": "0xf851a440", "implementation()": "0x5c60da1b",
    "getAllMarkets()": "0xb0772d0b", "markets(address)": "0x8e8f294b",
    "borrowGuardianPaused(address)": "0x6d154ea5", "mintGuardianPaused(address)": "0x731f0c2b",
    "borrowCaps(address)": "0x4a584432", "getUnderlyingPrice(address)": "0xfc57d4df",
    "aggregators(address)": "0x112cdab9", "borrowIndex()": "0xaa5af0fd",
    "closeFactorMantissa()": "0xe8755446", "liquidationIncentiveMantissa()": "0x4ada90af",
    "oracle()": "0x7dc0d1d0", "pauseGuardian()": "0x24a3d622",
    "comptrollerImplementation()": "0xbb82aa5e", "transferGuardianPaused()": "0x87f76303",
    "seizeGuardianPaused()": "0xac0b0bb7", "compRate()": "0xaa900754",
    "getCompAddress()": "0x9d1b5a0a", "compAccrued(address)": "0xcc7ebdc4",
    "getAssetsIn(address)": "0xabfceffc", "getAccountLiquidity(address)": "0x5ec88c79",
    "latestAnswer()": "0x50d25bcd", "latestRoundData()": "0xfeaf968c",
    "description()": "0x7284e416", "assetPrices(address)": "0x5e9a523c",
    "underlyingSymbols(address)": "0x7f3baaf2", "maxPriceDiff()": "0x05c552d8",
    "ref()": "0x21a78f68", "v1PriceOracle()": "0xfe10c98d",
}

def pad(a): return a[2:].lower().rjust(64, "0")

def post(payload, rpc=RPC):
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    for a in range(5):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=60).read())
        except Exception:
            if a == 4: raise
            time.sleep(1)

def call(to, sel, arg=None):
    data = SEL[sel] + (pad(arg) if arg else "")
    return ["eth_call", [{"to": to, "data": data}, "latest"]]

def fw(r):
    """first word decode; returns int or {'error'}"""
    if not isinstance(r, str) or len(r) < 66:
        return {"raw": r}
    return int(r[2:66], 16)

def fw_addr(r):
    v = fw(r)
    if isinstance(v, dict):
        return v
    return "0x" + hex(v)[2:].rjust(40, "0")

def decode_str(r):
    if not isinstance(r, str) or r == "0x":
        return r
    b = bytes.fromhex(r[2:])
    try:
        off = int.from_bytes(b[:32], "big")
        ln = int.from_bytes(b[off:off+32], "big")
        return b[off+32:off+32+ln].decode("utf-8", "replace")
    except Exception:
        return r

def main():
    bn = int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    raw = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                "params": [{"to": CTRL, "data": SEL["getAllMarkets()"]}, "latest"]})["result"]
    h = raw[2:]
    off = int(h[:64], 16); ln = int(h[off*2:off*2+64], 16)
    addrs = ["0x" + h[(off+32+i*32)*2+24:(off+32+i*32+32)*2] for i in range(ln)]

    out = {"block": bn, "markets": {}}
    for a in addrs:
        m = {}
        for f in ["symbol()", "name()", "underlying()", "decimals()", "getCash()", "totalSupply()",
                  "totalBorrows()", "totalReserves()", "exchangeRateStored()", "borrowIndex()",
                  "accrualBlockNumber()", "reserveFactorMantissa()", "borrowRatePerBlock()",
                  "supplyRatePerBlock()", "interestRateModel()", "admin()", "implementation()",
                  "markets(address)", "borrowGuardianPaused(address)", "mintGuardianPaused(address)",
                  "borrowCaps(address)", "getUnderlyingPrice(address)", "aggregators(address)"]:
            to = ORACLE if f in ("getUnderlyingPrice(address)", "aggregators(address)") else a
            arg = a if f.endswith("(address)") else None
            r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                      "params": [{"to": to, "data": SEL[f] + (pad(arg) if arg else "")}, "latest"]})
            m[f] = r.get("result", {"error": r.get("error")})
        # decode
        d = {}
        for f, r in m.items():
            if f in ("symbol()", "name()"):
                d[f] = decode_str(r)
            elif f in ("underlying()", "interestRateModel()", "admin()", "implementation()"):
                d[f] = fw_addr(r)
            elif f == "markets(address)":
                if isinstance(r, str) and len(r) >= 194:
                    d[f] = {"isListed": int(r[2:66], 16), "cf": int(r[66:130], 16), "isComped": int(r[130:194], 16)}
                else:
                    d[f] = {"error": r}
            elif f in ("aggregators(address)",):
                d[f] = fw_addr(r)
            else:
                d[f] = fw(r)
        # underlying balance + decimals
        und = d.get("underlying()")
        if isinstance(und, str):
            r1 = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": und, "data": SEL["decimals()"]}, "latest"]})
            r2 = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": und, "data": SEL["balanceOf(address)"] + pad(a)}, "latest"]})
            d["und_dec"] = fw(r1.get("result"))
            d["und_bal_market"] = fw(r2.get("result"))
        out["markets"][a] = d
        print(f"{d.get('symbol()')} {a} cash={d.get('getCash()')} borrows={d.get('totalBorrows()')}", file=sys.stderr)

    # comptroller-level
    cs = {}
    for f in ["closeFactorMantissa()", "liquidationIncentiveMantissa()", "oracle()", "pauseGuardian()",
              "admin()", "comptrollerImplementation()", "transferGuardianPaused()", "seizeGuardianPaused()",
              "compRate()", "getCompAddress()"]:
        r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                  "params": [{"to": CTRL, "data": SEL[f]}, "latest"]})
        v = r.get("result", {"error": r.get("error")})
        if f in ("oracle()", "pauseGuardian()", "admin()", "comptrollerImplementation()", "getCompAddress()"):
            cs[f] = fw_addr(v)
        else:
            cs[f] = fw(v)
    out["comptroller"] = cs

    # oracle-level
    o = {}
    for f in ["maxPriceDiff()", "ref()", "v1PriceOracle()"]:
        r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                  "params": [{"to": ORACLE, "data": SEL[f]}, "latest"]})
        v = r.get("result", {"error": r.get("error")})
        o[f] = fw_addr(v) if f in ("ref()", "v1PriceOracle()") else fw(v)
    out["oracle"] = o

    json.dump(out, open("/home/heisenberg/CA/scream/analysis/state.json", "w"), indent=2)
    print("saved block", bn)

if __name__ == "__main__":
    main()
