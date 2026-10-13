#!/usr/bin/env python3
"""Read Geist Finance (Fantom) live state via public RPC. Read-only. No secrets.
Usage: python3 read_state.py [block]
Writes JSON to stdout / analysis/live-state.json
"""
import json, sys, time, urllib.request

RPC = "https://rpcapi.fantom.network"
POOL = "0x9fad24f572045c7869117160a571b2e50b10d068"
PROVIDER = "0x6c793c628Fe2b480c5e6FB7957dDa4b9291F9c9b"
ORACLE = "0xC466e3FeE82C6bdc2E17f2eaF2c6F1E91AD10FD3"

_id = 0
def rpc_call(method, params, retries=4):
    global _id
    _id += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method, "params": params}).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research/read-only"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read())
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:
            if a == retries - 1:
                raise
            time.sleep(1.5 * (a + 1))

def batch(calls):
    """calls: list of (method, params). Returns results list. Chunked at 10."""
    global _id
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = []
        for m, p in chunk:
            _id += 1
            payload.append({"jsonrpc": "2.0", "id": _id, "method": m, "params": p})
        body = json.dumps(payload).encode()
        for a in range(4):
            try:
                req = urllib.request.Request(RPC, data=body, headers={
                    "Content-Type": "application/json",
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research/read-only"})
                with urllib.request.urlopen(req, timeout=40) as r:
                    d = json.loads(r.read())
                byid = {x["id"]: x for x in d}
                for item in payload:
                    res = byid.get(item["id"], {})
                    out.append(res.get("result") if "error" not in res else {"__error__": res["error"]})
                break
            except Exception:
                if a == 3:
                    out.extend([None]*len(chunk))
                time.sleep(2)
        time.sleep(0.3)
    return out

def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")
def enc_uint(n): return hex(n)[2:].rjust(64, "0")

def sel(sig):
    # keccak via eth-hash not available; hardcode selectors we need
    S = {
        "symbol()": "0x95d89b41", "decimals()": "0x313ce567", "name()": "0x06fdde03",
        "totalSupply()": "0x18160ddd", "scaledTotalSupply()": "0xb1bf962d",
        "getReservesList()": "0xd1946dbc",
        "getReserveData(address)": "0x35ea6a75",
        "getReserveConfigurationData(address)": "0x3e150141",
        "getReserveNormalizedIncome(address)": "0xd15e0053",
        "getReserveNormalizedVariableDebt(address)": "0x386497fd",
        "getUserAccountData(address)": "0xbf92857c",
        "getAssetPrice(address)": "0xb3596f07",
        "getLendingPool()": "0x0261bf8b",
        "getPriceOracle()": "0xfca513a8",
        "getPoolAdmin()": "0xaecda378",
        "getEmergencyAdmin()": "0xddcaa9ea",
        "getLendingPoolConfigurator()": "0x85c858b1",
        "getLendingPoolCollateralManager()": "0x712d9171",
        "getAddressesProvider()": "0xfe65acfe",
        "paused()": "0x5c975abb",
        "UNDERLYING_ASSET_ADDRESS()": "0xb16a19de",
        "POOL()": "0x7535d246",
        "getAllATokens()": "0xf561ae41",
        "getAllReservesTokens()": "0xb316ff89",
    }
    return S[sig]

def call(to, sig, args=""):
    return ["eth_call", [{"to": to, "data": sel(sig) + args}, "latest"]]

def dec_uint(hexs):
    if not isinstance(hexs, str) or hexs in ("0x",):
        return None
    return int(hexs, 16)

def dec_addr(word):
    return "0x" + word[-40:]

def dec_string(hexs):
    """decode abi-encoded string return"""
    if not isinstance(hexs, str) or len(hexs) < 130:
        return None
    b = bytes.fromhex(hexs[2:])
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off+32], "big")
        return b[off+32:off+32+ln].decode("utf-8", "replace")
    except Exception:
        return None

def main():
    block = sys.argv[1] if len(sys.argv) > 1 else "latest"
    blk = rpc_call("eth_blockNumber", [])
    print(f"# latest block {int(blk,16)}", file=sys.stderr)

    # 1. reserves list
    res = rpc_call("eth_call", [{"to": POOL, "data": sel("getReservesList()")}, "latest"])
    b = bytes.fromhex(res[2:])
    n = int.from_bytes(b[32:64], "big")          # dynamic array: word0=offset, word1=length
    assets = ["0x" + b[64+i*32+12:64+i*32+32].hex() for i in range(n)]
    print(f"# {n} reserves: {assets}", file=sys.stderr)

    state = {"block": int(blk, 16), "pool": POOL, "provider": PROVIDER,
             "oracle": ORACLE, "reserves": []}

    # provider reads
    pv = batch([call(PROVIDER, "getLendingPool()"), call(PROVIDER, "getPriceOracle()"),
                call(PROVIDER, "getPoolAdmin()"), call(PROVIDER, "getEmergencyAdmin()"),
                call(PROVIDER, "getLendingPoolConfigurator()"),
                call(PROVIDER, "getLendingPoolCollateralManager()")])
    state["provider_reads"] = {
        "lendingPool": dec_addr(pv[0]) if pv[0] else None,
        "priceOracle": dec_addr(pv[1]) if pv[1] else None,
        "poolAdmin": dec_addr(pv[2]) if pv[2] else None,
        "emergencyAdmin": dec_addr(pv[3]) if pv[3] else None,
        "configurator": dec_addr(pv[4]) if pv[4] else None,
        "collateralManager": dec_addr(pv[5]) if pv[5] else None,
    }
    state["paused"] = dec_uint(batch([call(POOL, "paused()")])[0])

    for asset in assets:
        a = asset.lower()
        # getReserveData
        rd = rpc_call("eth_call", [{"to": POOL, "data": sel("getReserveData(address)") + enc_addr(a)}, "latest"])
        bb = bytes.fromhex(rd[2:])
        # Geist ReserveData (12 words): config, liqIdx, varIdx, curLiqRate, curVarBorrowRate,
        # curStableBorrowRate, lastUpdateTimestamp, aToken, stableDebt, variableDebt, irs, id
        conf = int.from_bytes(bb[0:32], "big")
        liq_idx = int.from_bytes(bb[32:64], "big")
        var_idx = int.from_bytes(bb[64:96], "big")
        cur_liq_rate = int.from_bytes(bb[96:128], "big")
        cur_var_rate = int.from_bytes(bb[128:160], "big")
        cur_stable_rate = int.from_bytes(bb[160:192], "big")
        ts = int.from_bytes(bb[192:224], "big")
        aToken = "0x" + bb[224+12:256].hex()
        stableDebt = "0x" + bb[256+12:288].hex()
        varDebt = "0x" + bb[288+12:320].hex()
        irs = "0x" + bb[320+12:352].hex()
        rid = int.from_bytes(bb[352:384], "big")

        sym, dec, cdata, price, cash, tsupply, ssupply, vdebt, sdebt, nincome, nvdebt = batch([
            call(a, "symbol()"), call(a, "decimals()"),
            call(POOL, "getReserveConfigurationData(address)", enc_addr(a)),
            call(ORACLE, "getAssetPrice(address)", enc_addr(a)),
            call(a, "totalSupply()"),  # placeholder replaced below
            call(aToken, "totalSupply()"),
            call(aToken, "scaledTotalSupply()"),
            call(varDebt, "totalSupply()"),
            call(stableDebt, "totalSupply()"),
            call(POOL, "getReserveNormalizedIncome(address)", enc_addr(a)),
            call(POOL, "getReserveNormalizedVariableDebt(address)", enc_addr(a)),
        ])
        # cash = underlying.balanceOf(aToken)
        cash = dec_uint(rpc_call("eth_call", [{"to": a, "data": "0x70a08231" + enc_addr(aToken)}, "latest"]))
        dec_ = dec_uint(dec) if dec is not None else None
        cfields = None
        if isinstance(cdata, str) and len(cdata) >= 2 + 64*10:
            cb = bytes.fromhex(cdata[2:])
            cfields = {
                "decimals": int.from_bytes(cb[0:32], "big"),
                "ltv": int.from_bytes(cb[32:64], "big"),
                "liquidationThreshold": int.from_bytes(cb[64:96], "big"),
                "liquidationBonus": int.from_bytes(cb[96:128], "big"),
                "reserveFactor": int.from_bytes(cb[128:160], "big"),
                "usageAsCollateralEnabled": bool(int.from_bytes(cb[160:192], "big")),
                "borrowingEnabled": bool(int.from_bytes(cb[192:224], "big")),
                "stableBorrowRateEnabled": bool(int.from_bytes(cb[224:256], "big")),
                "isActive": bool(int.from_bytes(cb[256:288], "big")),
                "isFrozen": bool(int.from_bytes(cb[288:320], "big")),
            }
        state["reserves"].append({
            "asset": a, "symbol": dec_string(sym), "decimals": dec_,
            "reserveConfigMap": hex(conf),
            "liquidityIndex": str(liq_idx), "variableBorrowIndex": str(var_idx),
            "currentLiquidityRate": str(cur_liq_rate),
            "currentVariableBorrowRate": str(cur_var_rate),
            "currentStableBorrowRate": str(cur_stable_rate),
            "lastUpdateTimestamp": ts,
            "aToken": aToken, "stableDebtToken": stableDebt, "variableDebtToken": varDebt,
            "interestRateStrategy": irs, "id": rid,
            "config": cfields,
            "oraclePrice": str(dec_uint(price)) if price else None,
            "aTokenCashUnderlying": str(cash) if cash is not None else None,
            "aTokenTotalSupply": str(dec_uint(tsupply)) if tsupply else None,
            "aTokenScaledTotalSupply": str(dec_uint(ssupply)) if ssupply else None,
            "variableDebtTotalSupply": str(dec_uint(vdebt)) if vdebt else None,
            "stableDebtTotalSupply": str(dec_uint(sdebt)) if sdebt else None,
            "reserveNormalizedIncome": str(dec_uint(nincome)) if nincome else None,
            "reserveNormalizedVariableDebt": str(dec_uint(nvdebt)) if nvdebt else None,
        })
        print(f"# {dec_string(sym)} ({a}) cash={cash}", file=sys.stderr)
        time.sleep(0.2)

    print(json.dumps(state, indent=1))

if __name__ == "__main__":
    main()
