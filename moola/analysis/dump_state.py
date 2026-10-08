#!/usr/bin/env python3
"""Dump Moola (Celo) full reserve state at latest block. Read-only."""
import json, sys, urllib.request, subprocess, os

RPC = "https://forno.celo.org"
POOL = "0x970b12522CA9b4054807a2c5B736149a5BE6f670"
PROVIDER = "0xD1088091A174d33412a968Fa34Cb67131188B332"
ORACLE = "0xBa2224905Ad3CDbA6c1b764CD62FDa52bd524d29"

RESERVES = {
    "CELO":  "0x471EcE3750Da237f93B8E339c536989b8978a438",
    "cUSD":  "0x765DE816845861e75A25fCA122bb6898B8B1282a",
    "cEUR":  "0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73",
    "cREAL": "0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787",
    "MOO":   "0x17700282592D6917F6A73D0bF8AcCf4D578c131e",
}

SEL = {
 "paused":"0x5c975abb",
 "getAddressesProvider":"0xfe65acfe",
 "getPriceOracle":"0xfca513a8",
 "getLendingPoolConfigurator":"0x85c858b1",
 "getLendingPoolCollateralManager":"0x712d9171",
 "FLASHLOAN_PREMIUM_TOTAL":"0x074b2e43",
 "MAX_NUMBER_RESERVES":"0xf8119d51",
 "getFallbackOracle":"0x6210308c",
 "owner":"0x8da5cb5b",
 "getPoolAdmin":"0xaecda378",
 "getEmergencyAdmin":"0xddcaa9ea",
 "totalSupply":"0x18160ddd",
 "scaledTotalSupply":"0xb1bf962d",
 "decimals":"0x313ce567",
 "RESERVE_TREASURY_ADDRESS":"0xae167335",
 "balanceOf":"0x70a08231",
 "getReserveNormalizedIncome":"0xd15e0053",
 "getReserveData":"0x35ea6a75",
 "getAssetPrice":"0xb3596f07",
 "getUserAccountData":"0xbf92857c",
 "getPoolAdminProvider":"0xaecda378",
}

_id = 0
def rpc(method, params):
    global _id
    _id += 1
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc":"2.0","id":_id,"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"moola-audit/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    if "error" in d: raise RuntimeError(d["error"])
    return d["result"]

def call(sel, to, arg=None):
    data = sel + (arg[2:].rjust(64,"0") if arg else "")
    blk = os.environ.get("BLOCK")
    blkparam = hex(int(blk)) if blk else "latest"
    return rpc("eth_call", [{"to":to,"data":data},blkparam])

def as_int(h): return int(h,16) if h and h not in ("0x",None) else None
def as_addr(h): return "0x"+h[-40:] if h and h != "0x" else None

def decode_config(d):
    return {"LTV_bps": d & 0xFFFF, "liqThreshold_bps": (d>>16)&0xFFFF,
            "liqBonus_bps": (d>>32)&0xFFFF, "decimals": (d>>48)&0xFF,
            "isActive": (d>>56)&1, "isFrozen": (d>>57)&1,
            "borrowingEnabled": (d>>58)&1, "stableEnabled": (d>>59)&1,
            "isPaused": (d>>60)&1, "reserveFactor_bps": (d>>64)&0xFFFF}

def main():
    from eth_abi import decode
    blk = as_int(rpc("eth_blockNumber", []))
    out = {"block": int(os.environ.get("BLOCK", blk)), "head_at_call": blk, "pool": POOL, "reserves": {}}
    out["paused"] = bool(as_int(call(SEL["paused"], POOL)))
    out["provider"] = as_addr(call(SEL["getAddressesProvider"], POOL))
    pa = out["provider"]
    out["provider_info"] = {}
    for k,sel in [("priceOracle",SEL["getPriceOracle"]),
                  ("poolAdmin",SEL["getPoolAdmin"]),
                  ("emergencyAdmin",SEL["getEmergencyAdmin"]),
                  ("configurator",SEL["getLendingPoolConfigurator"]),
                  ("collateralManager",SEL["getLendingPoolCollateralManager"]),
                  ("owner",SEL["owner"])]:
        try: out["provider_info"][k] = as_addr(call(sel, pa))
        except Exception as e: out["provider_info"][k] = f"ERR {e}"
    out["flashloan_premium_bps"] = as_int(call(SEL["FLASHLOAN_PREMIUM_TOTAL"], POOL))
    out["max_reserves"] = as_int(call(SEL["MAX_NUMBER_RESERVES"], POOL))
    out["oracle"] = out["provider_info"]["priceOracle"]
    out["fallback_oracle"] = as_addr(call(SEL["getFallbackOracle"], ORACLE))

    types = ["(uint256,uint128,uint128,uint128,uint128,uint128,uint40,address,address,address,address,uint8)"]
    for name, asset in RESERVES.items():
        r = call(SEL["getReserveData"], POOL, asset)
        (cfg, liq_idx, var_idx, liq_rate, var_rate, stab_rate, ts,
         aTok, sDebt, vDebt, strat, rid) = decode(types, bytes.fromhex(r[2:]))[0]
        price = as_int(call(SEL["getAssetPrice"], ORACLE, asset))
        rd = {"asset": asset, "config_hex": hex(cfg), "config": decode_config(cfg),
              "liquidityIndex": liq_idx, "variableBorrowIndex": var_idx,
              "currentLiquidityRate_ray": liq_rate, "currentVariableBorrowRate_ray": var_rate,
              "currentStableBorrowRate_ray": stab_rate, "lastUpdateTimestamp": ts,
              "aToken": aTok, "stableDebtToken": sDebt, "variableDebtToken": vDebt,
              "strategy": strat, "id": rid, "oracle_price_celo": price}
        rd["aToken_totalSupply"] = as_int(call(SEL["totalSupply"], aTok))
        rd["aToken_scaledTotalSupply"] = as_int(call(SEL["scaledTotalSupply"], aTok))
        rd["cash_underlying"] = as_int(call(SEL["balanceOf"], asset, aTok))
        treasury = as_addr(call(SEL["RESERVE_TREASURY_ADDRESS"], aTok))
        rd["treasury"] = treasury
        rd["treasury_atoken_bal"] = as_int(call(SEL["balanceOf"], aTok, treasury))
        def try_call(sel, to, arg=None):
            try: return as_int(call(sel, to, arg))
            except Exception: return None
        rd["stableDebt_totalSupply"] = try_call(SEL["totalSupply"], sDebt)
        rd["stableDebt_scaledTotalSupply"] = try_call(SEL["scaledTotalSupply"], sDebt)
        rd["variableDebt_totalSupply"] = try_call(SEL["totalSupply"], vDebt)
        rd["variableDebt_scaledTotalSupply"] = try_call(SEL["scaledTotalSupply"], vDebt)
        rd["aToken_decimals"] = try_call(SEL["decimals"], aTok)
        rd["aToken_underlying"] = as_addr(call("0xb16a19de", aTok))
        out["reserves"][name] = rd
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    try:
        import eth_abi
    except ImportError:
        subprocess.check_call([sys.executable,"-m","pip","install","--quiet","eth_abi","eth_utils"])
    main()
