#!/usr/bin/env python3
"""CrediX (Sonic) full on-chain enumeration. Read-only. Saves raw JSON."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
os.makedirs(RAW, exist_ok=True)

SEL = {
    "getReservesList": "0xd1946dbc",
    "getReserveData": "0x35ea6a75",
    "getAllReservesTokens": "0xb316ff89",
    "getReserveTokensAddresses": "0xd2493b6c",
    "getReserveConfigurationData": "0x3e150141",
    "symbol": "0x95d89b41",
    "name": "0x06fdde03",
    "decimals": "0x313ce567",
    "balanceOf": "0x70a08231",
    "totalSupply": "0x18160ddd",
    "scaledTotalSupply": "0xb1bf962d",
    "getReserveNormalizedIncome": "0xd15e0053",
    "getReserveNormalizedVariableDebt": "0x386497fd",
    "getUserAccountData": "0xbf92857c",
    "getPoolDataProvider": "0x5d10c393",  # placeholder not used
}

# PoolAddressesProvider getters (verified selectors)
PROV = {
    "getPool": "0x026b1d5f",
    "getPoolConfigurator": "0x631adfca",
    "getPriceOracle": "0xfca513a8",
    "getACLManager": "0x707cd716",
    "getACLAdmin": "0x0e67178c",
    "getPoolDataProvider": "0xe860accb",
    "getPriceOracleSentinel": "0x5eb88d3d",
    "owner": "0x8da5cb5b",
    "getMarketId": "0x568ef470",
}

MARKETS = {
    "A_stability": {
        "provider": "0x4b139f6E816934D580D9305Ca0f115145f698973",
        "pool": "0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E",
        "aclManager_hint": "0x1637b78Dd5541F0dB2f3d04EeD39De37Df71BD08",
    },
    "B_core": {
        "provider": "0x282eDE6BbD2d224D454C995e66f08569A5508e9a",
        "pool": "0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e",
        "aclManager_hint": "0x8f0431F6Adb3e81D282d0508c16e2817DC95095b",
    },
}


def call_one(to, selector, block="latest"):
    return rpc("eth_call", [{"to": to, "data": selector}, block])


def call_many(to, datas, block="latest"):
    calls = [("eth_call", [{"to": to, "data": d}, block]) for d in datas]
    return batch(calls)


def dec_str_word(hexstr):
    """Decode a single dynamic string return."""
    try:
        h = hexstr[2:]
        if len(h) < 128:
            return None
        ln = int(h[64:128], 16)
        return bytes.fromhex(h[128:128 + ln * 2]).decode("utf-8", "replace")
    except Exception:
        return None


def decode_reserve_data(hexstr):
    h = hexstr[2:]
    words = [h[i * 64:(i + 1) * 64] for i in range(len(h) // 64)]
    if len(words) < 15:
        return {"raw": hexstr, "error": "too short", "nwords": len(words)}
    return {
        "configuration": int(words[0], 16),
        "liquidityIndex": int(words[1], 16),
        "currentLiquidityRate": int(words[2], 16),
        "variableBorrowIndex": int(words[3], 16),
        "currentVariableBorrowRate": int(words[4], 16),
        "currentStableBorrowRate": int(words[5], 16),
        "lastUpdateTimestamp": int(words[6], 16),
        "id": int(words[7], 16),
        "aTokenAddress": addr_from_word(words[8]),
        "stableDebtTokenAddress": addr_from_word(words[9]),
        "variableDebtTokenAddress": addr_from_word(words[10]),
        "interestRateStrategyAddress": addr_from_word(words[11]),
        "accruedToTreasury": int(words[12], 16),
        "unbacked": int(words[13], 16),
        "isolationModeTotalDebt": int(words[14], 16),
        "raw": hexstr,
    }


def decode_config(cfg):
    return {
        "ltv": cfg & 0xFFFF,
        "liquidationThreshold": (cfg >> 16) & 0xFFFF,
        "liquidationBonus": (cfg >> 32) & 0xFFFF,
        "decimals": (cfg >> 48) & 0xFF,
        "isActive": (cfg >> 56) & 1,
        "isFrozen": (cfg >> 57) & 1,
        "borrowingEnabled": (cfg >> 58) & 1,
        "stableBorrowRateEnabled": (cfg >> 59) & 1,
        "isPaused": (cfg >> 60) & 1,
        "flashLoanEnabled": (cfg >> 63) & 1,
    }


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    print("block", block)
    out = {"block": block, "markets": {}}

    for name, m in MARKETS.items():
        entry = dict(m)
        # provider getters
        datas = [PROV[k] for k in PROV]
        res = call_many(m["provider"], datas, hex(block))
        for k, v in zip(PROV, res):
            if isinstance(v, dict) and "error" in v:
                entry[k] = {"error": v["error"]}
            elif k == "getMarketId":
                entry[k] = dec_str_word(v) if v else None
            elif k == "owner":
                entry[k] = addr_from_word(v) if v else None
            else:
                entry[k] = addr_from_word(v) if v else None

        # reserves list
        rl = call_one(m["pool"], SEL["getReservesList"], hex(block))
        if isinstance(rl, dict):
            entry["reserves_error"] = rl
            out["markets"][name] = entry
            continue
        h = rl[2:]
        n = int(h[64:128], 16) if len(h) >= 128 else 0
        reserves = [addr_from_word(h[128 + i * 64:192 + i * 64]) for i in range(n)]
        entry["reserves"] = []
        for asset in reserves:
            r = {}
            r["asset"] = asset
            rd = call_one(m["pool"], SEL["getReserveData"] + asset[2:].rjust(64, "0"), hex(block))
            r["reserveData"] = decode_reserve_data(rd) if isinstance(rd, str) else {"error": rd}
            # token metadata
            tsym, tname, tdec = call_many(asset, [SEL["symbol"], SEL["name"], SEL["decimals"]], hex(block))
            r["symbol"] = dec_str_word(tsym) if isinstance(tsym, str) else None
            r["name"] = dec_str_word(tname) if isinstance(tname, str) else None
            r["decimals"] = dec_u(tdec) if isinstance(tdec, str) else None
            entry["reserves"].append(r)

        # data provider extras
        dp = entry.get("getPoolDataProvider")
        if dp and dp != "0x0000000000000000000000000000000000000000":
            art = call_one(dp, SEL["getAllReservesTokens"], hex(block))
            entry["dataProvider_getAllReservesTokens_raw"] = art
        out["markets"][name] = entry
        print(f"[{name}] pool={m['pool']} reserves={len(entry.get('reserves', []))}")

    with open(os.path.join(RAW, "enumeration.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("saved", os.path.join(RAW, "enumeration.json"))


if __name__ == "__main__":
    main()
