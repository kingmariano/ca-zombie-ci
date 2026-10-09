#!/usr/bin/env python3
"""Enumerate YeiLend pools (Sei): reserves, tokens, oracle prices+source, configs. Read-only."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/yeilend/analysis")
from rpc import rpc, eth_call, block_number, SEL, words, dec_uint, dec_addr, dec_string

POOLS = {
    "pool1_0x4a4d": {"pool": "0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638",
                     "oracle": "0xA1ce28cEbaB91d8dF346D19970E4Ee69A6989734",
                     "provider": "0x5C57266688A4aD1d3aB61209ebcb967B84227642"},
    "pool2_0x7b5b": {"pool": "0x7b5b1A719d54664657451db7600FD5C3ca0fa136",
                     "oracle": "0xbDecf329328CD5A8b0035697163b61d7268887AE",
                     "provider": "0xfF33A79d9190bD63D0E9A4946f7FcCbA0e8f2A1e"},
}

def call_sel(to, sig, arg=None, block=None):
    sel = "0x" + SEL[sig] + (arg[2:].rjust(64, "0") if arg else "")
    return eth_call(to, sel, block)

def conf_decode(c):
    return {
        "ltv_bp": c & 0xFFFF,
        "lt_bp": (c >> 16) & 0xFFFF,
        "bonus_bp": (c >> 32) & 0xFFFF,
        "reserve_decimals": (c >> 48) & 0xFF,
        "active": (c >> 56) & 1,
        "frozen": (c >> 57) & 1,
        "borrowingEnabled": (c >> 58) & 1,
        "stableBorrowRateEnabled": (c >> 59) & 1,
        "paused": (c >> 60) & 1,
        "borrowableInIsolation": (c >> 61) & 1,
        "siloedBorrowing": (c >> 62) & 1,
        "flashLoanEnabled": (c >> 63) & 1,
        "reserveFactor_bp": (c >> 64) & 0xFFFF,
        "borrowCap": (c >> 80) & ((1 << 36) - 1),
        "supplyCap": (c >> 116) & ((1 << 36) - 1),
        "liqProtocolFee_bp": (c >> 152) & 0xFFFF,
        "eModeCategory": (c >> 168) & 0xFF,
        "unbackedMintCap": (c >> 176) & ((1 << 36) - 1),
        "debtCeiling": (c >> 212) & ((1 << 40) - 1),
        "forcedLiquidationEnabled": (c >> 252) & 1,
    }

def read_erc20(a, block):
    out = {"address": a}
    for k, sig in [("symbol", "symbol()"), ("decimals", "decimals()"), ("totalSupply", "totalSupply()")]:
        try:
            r = call_sel(a, sig, None, block)
            if k == "symbol":
                out[k] = dec_string(r)
            elif k == "decimals":
                out[k] = dec_uint(r[2:])
            else:
                out[k] = dec_uint(r[2:])
        except Exception as e:
            out[k] = None
    return out

def main(out):
    blk = block_number()
    res = {"block": blk, "pools": {}}
    for pname, cfg in POOLS.items():
        pool, oracle = cfg["pool"], cfg["oracle"]
        print(pname, "block", blk)
        raw = call_sel(pool, "getReservesList()")
        h = raw[2:]
        off = int(h[:64], 16) * 2
        n = int(h[off:off + 64], 16)
        addrs = [dec_addr(h[off + 64 + i * 64: off + 64 + i * 64 + 64]) for i in range(n)]
        pinfo = {"pool": pool, "oracle": oracle, "provider": cfg["provider"], "n_reserves": n, "reserves": []}
        for a in addrs:
            u = read_erc20(a, blk)
            d = call_sel(pool, "getReserveData(address)", a, blk)
            w = words(d)
            price = dec_uint(call_sel(oracle, "getAssetPrice(address)", a, blk)[2:])
            try:
                src = dec_addr(call_sel(oracle, "getSourceOfAsset(address)", a, blk)[2:])
            except Exception:
                src = None
            rd = {
                "asset": a, "symbol": u["symbol"], "decimals": u["decimals"],
                "underlying_totalSupply": u["totalSupply"],
                "config_raw": w[0], "conf": conf_decode(int(w[0], 16)),
                "liquidityIndex": dec_uint(w[1]),
                "currentLiquidityRate": dec_uint(w[2]),
                "variableBorrowIndex": dec_uint(w[3]),
                "currentVariableBorrowRate": dec_uint(w[4]),
                "lastUpdateTimestamp": dec_uint(w[6]),
                "id": dec_uint(w[7]),
                "aToken": dec_addr(w[8]), "stableDebtToken": dec_addr(w[9]),
                "variableDebtToken": dec_addr(w[10]), "interestRateStrategy": dec_addr(w[11]),
                "accruedToTreasury": dec_uint(w[12]), "unbacked": dec_uint(w[13]),
                "isolationModeTotalDebt": dec_uint(w[14]),
                "oraclePrice": price,
                "oracleSource": src,
            }
            # aToken actual + scaled supply, debt totals, underlying held by aToken
            try:
                rd["aToken_totalSupply"] = dec_uint(call_sel(rd["aToken"], "totalSupply()", None, blk)[2:])
            except Exception:
                rd["aToken_totalSupply"] = None
            try:
                rd["aToken_scaledTotalSupply"] = dec_uint(call_sel(rd["aToken"], "scaledTotalSupply()", None, blk)[2:])
            except Exception:
                rd["aToken_scaledTotalSupply"] = None
            try:
                rd["vDebtTotalSupply"] = dec_uint(call_sel(rd["variableDebtToken"], "totalSupply()", None, blk)[2:])
            except Exception:
                rd["vDebtTotalSupply"] = None
            try:
                rd["vDebtScaledTotalSupply"] = dec_uint(call_sel(rd["variableDebtToken"], "scaledTotalSupply()", None, blk)[2:])
            except Exception:
                rd["vDebtScaledTotalSupply"] = None
            try:
                rd["aToken_underlying_balance"] = dec_uint(call_sel(a, "balanceOf(address)", rd["aToken"], blk)[2:])
            except Exception:
                rd["aToken_underlying_balance"] = None
            # source details
            try:
                sc = rpc("eth_getCode", [src, hex(blk)])
                rd["oracleSource_code_size"] = (len(sc) - 2) // 2 if sc and sc != "0x" else 0
                if rd["oracleSource_code_size"] > 0:
                    try:
                        rd["oracleSource_latestAnswer"] = dec_uint(call_sel(src, "latestAnswer()", None, blk)[2:])
                    except Exception as e:
                        rd["oracleSource_latestAnswer"] = None
                    try:
                        rd["oracleSource_owner"] = dec_addr(call_sel(src, "owner()", None, blk)[2:])
                    except Exception:
                        rd["oracleSource_owner"] = None
            except Exception:
                rd["oracleSource_code_size"] = None
            pinfo["reserves"].append(rd)
            print(f"  {rd['symbol']:<12} dec={rd['decimals']} price={rd['oraclePrice']} src={src} ltv={rd['conf']['ltv_bp']} lt={rd['conf']['lt_bp']} bonus={rd['conf']['bonus_bp']} active={rd['conf']['active']} frozen={rd['conf']['frozen']} paused={rd['conf']['paused']} aSupply={rd['aToken_totalSupply']} vDebt={rd['vDebtTotalSupply']}")
        res["pools"][pname] = pinfo
    json.dump(res, open(out, "w"), indent=1)
    print("wrote", out)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "analysis/reserves_raw.json")
