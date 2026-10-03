#!/usr/bin/env python3
"""Fetch full Scream (Fantom) market state via JSON-RPC batch. Read-only."""
import json, sys, time, urllib.request

RPC = "https://rpcapi.fantom.network"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"

SEL = {
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "decimals()": "0x313ce567",
    "balanceOf(address)": "0x70a08231",
    "underlying()": "0x6f307dc3",
    "cash()": "0x961be391",
    "totalSupply()": "0x18160ddd",
    "totalBorrows()": "0x47bd3718",
    "totalReserves()": "0x8f840ddd",
    "exchangeRateStored()": "0x182df0f5",
    "accrualBlockNumber()": "0x6c540baf",
    "reserveFactorMantissa()": "0x173b9904",
    "borrowRatePerBlock()": "0xf8f9da28",
    "supplyRatePerBlock()": "0xae9d70b0",
    "interestRateModel()": "0xf3fdb15a",
    "comptroller()": "0x5fe3b567",
    "admin()": "0xf851a440",
    "implementation()": "0x5c60da1b",
    "getAllMarkets()": "0xb0772d0b",
    "markets(address)": "0x8e8f294b",
    "borrowGuardianPaused(address)": "0x6d154ea5",
    "mintGuardianPaused(address)": "0x731f0c2b",
    "borrowCaps(address)": "0x4a584432",
    "getUnderlyingPrice(address)": "0xfc57d4df",
    "transferGuardianPaused()": "0x87f76303",
    "seizeGuardianPaused()": "0xac0b0bb7",
    "comptrollerImplementation()": "0xbb82aa5e",
    "pauseGuardian()": "0x24a3d622",
    "oracle()": "0x7dc0d1d0",
    "closeFactorMantissa()": "0xe8755446",
    "liquidationIncentiveMantissa()": "0x4ada90af",
    "liquidationBlock()": "0xa22ca2a7",  # guess, may fail
    "getAssetsIn(address)": "0xabfceffc",
}

def pad(addr):
    return addr[2:].lower().rjust(64, "0")

def rpc_batch(calls, rpc=RPC):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(chunk)]
        data = json.dumps(payload).encode()
        req = urllib.request.Request(rpc, data=data,
                                     headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
        resp = None
        for attempt in range(4):
            try:
                resp = json.loads(urllib.request.urlopen(req, timeout=40).read())
                break
            except Exception as e:
                if attempt == 3:
                    raise
                time.sleep(1.5)
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r["result"] if "result" in r else {"error": r.get("error")})
    return out

def ecall(to, sig, arg=None, block="latest"):
    data = SEL[sig] + (pad(arg) if arg else "")
    return ["eth_call", [{"to": to, "data": data}, block]]

def decode_addr(h):
    return "0x" + h[-40:] if h and len(h) >= 42 else None

def decode_uint(h):
    return int(h, 16) if h and h not in ("0x", "0x0") else (0 if h == "0x0" else None)

def decode_str(h):
    if not h or h == "0x": return None
    b = bytes.fromhex(h[2:])
    try:
        if len(b) >= 64:
            off = int.from_bytes(b[:32], "big")
            ln = int.from_bytes(b[off:off+32], "big")
            return b[off+32:off+32+ln].decode("utf-8", "replace")
        return b.decode("utf-8", "replace")
    except Exception:
        return None

def main():
    bn = int(rpc_batch([["eth_blockNumber", []]])[0], 16)
    raw = rpc_batch([ecall(CTRL, "getAllMarkets()")])[0]
    h = raw[2:]
    off = int.from_bytes(bytes.fromhex(h[:64]), "big")
    ln = int.from_bytes(bytes.fromhex(h[off*2:off*2+64]), "big")
    addrs = ["0x" + h[(off+32+i*32)*2+24:(off+32+i*32+32)*2] for i in range(ln)]

    result = {"block": bn, "comptroller": CTRL, "market_count": len(addrs), "markets": {}}

    ctrl_fields = ["closeFactorMantissa()", "liquidationIncentiveMantissa()", "oracle()",
                   "pauseGuardian()", "admin()", "comptrollerImplementation()",
                   "transferGuardianPaused()", "seizeGuardianPaused()"]
    ctrl_res = rpc_batch([ecall(CTRL, f) for f in ctrl_fields])
    cs = {}
    for f, r in zip(ctrl_fields, ctrl_res):
        if isinstance(r, dict):
            cs[f] = {"error": r.get("error")}
        elif "Mantissa" in f:
            cs[f] = decode_uint(r)
        elif f.endswith("Paused()"):
            cs[f] = decode_uint(r)
        else:
            cs[f] = decode_addr(r)
    result["comptroller_state"] = cs
    oracle = cs.get("oracle()")

    fields = ["symbol()", "name()", "underlying()", "cash()", "totalSupply()", "totalBorrows()",
              "totalReserves()", "exchangeRateStored()", "accrualBlockNumber()",
              "reserveFactorMantissa()", "borrowRatePerBlock()", "supplyRatePerBlock()",
              "interestRateModel()", "comptroller()", "admin()", "implementation()"]
    for a in addrs:
        m = {}
        for f in fields:
            m[f] = ecall(a, f)
        m["markets(a)"] = ecall(CTRL, "markets(address)", a)
        m["borrowGuardianPaused(a)"] = ecall(CTRL, "borrowGuardianPaused(address)", a)
        m["mintGuardianPaused(a)"] = ecall(CTRL, "mintGuardianPaused(address)", a)
        m["borrowCaps(a)"] = ecall(CTRL, "borrowCaps(address)", a)
        m["getUnderlyingPrice(a)"] = ecall(oracle, "getUnderlyingPrice(address)", a)
        keys = list(m.keys())
        res = rpc_batch([m[k] for k in keys])
        d = {}
        for k, r in zip(keys, res):
            if isinstance(r, dict):
                d[k] = {"error": r.get("error")}
            elif k in ("symbol()", "name()"):
                d[k] = decode_str(r)
            elif k in ("underlying()", "interestRateModel()", "comptroller()", "admin()", "implementation()"):
                d[k] = decode_addr(r)
            elif k == "markets(a)":
                hh = r[2:]
                d[k] = {"isListed": decode_uint("0x" + hh[0:64]),
                        "collateralFactorMantissa": decode_uint("0x" + hh[64:128]),
                        "isComped": decode_uint("0x" + hh[128:192])}
            else:
                d[k] = decode_uint(r)
        # underlying decimals + balanceOf(market)
        und = d.get("underlying()")
        if und and not isinstance(und, dict):
            rr = rpc_batch([ecall(und, "decimals()"), ecall(und, "balanceOf(address)", a)])
            d["underlying_decimals"] = decode_uint(rr[0]) if not isinstance(rr[0], dict) else rr[0]
            d["underlying_balanceOf_market"] = decode_uint(rr[1]) if not isinstance(rr[1], dict) else rr[1]
        result["markets"][a] = d
        print(f"fetched {d.get('symbol()')} {a}", file=sys.stderr)

    with open("/home/heisenberg/CA/scream/analysis/markets.json", "w") as f:
        json.dump(result, f, indent=2)
    print(json.dumps({"block": bn, "count": len(addrs)}))

if __name__ == "__main__":
    main()
