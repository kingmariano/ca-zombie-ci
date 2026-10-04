#!/usr/bin/env python3
"""Decode Aave V3 ReserveConfigurationMap + summarize reserve state from saved files."""
import json, re, sys

CFG = {
    "LTV": (0, 0xFFFF),
    "liqThreshold": (16, 0xFFFF),
    "liqBonus": (32, 0xFFFF),
    "decimals": (48, 0xFF),
    "active": (56, 1),
    "frozen": (57, 1),
    "borrowingEnabled": (58, 1),
    "stableBorrowEnabled": (59, 1),
    "paused": (60, 1),
    "flashLoanEnabled": (61, 1),
    "reserveFactor": (64, 0xFFFF),
    "borrowCap": (80, 0xFFFFFFFFF),
    "supplyCap": (116, 0xFFFFFFFFF),
    "liqProtocolFee": (152, 0xFFFF),
    "eModeCategory": (168, 0xFF),
    "unbackedMintCap": (176, 0xFFFFFFFFF),
    "debtCeiling": (212, 0xFFFFFFFFF),
}

def decode(cfg):
    out = {}
    for name, (shift, mask) in CFG.items():
        v = (cfg >> shift) & mask
        out[name] = v
    return out

if __name__ == "__main__":
    # parse reservedata files: first field is the config inside parens
    reserves = []
    names = {
        "0x4c078361FC9BbB78DF910800A991C7c3DD2F6ce0": "mDAI",
        "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000": "METIS",
        "0xEA32A96608495e54156Ae48931A7c20f0dcc1a21": "mUSDC",
        "0xbB06DCA3AE6887fAbF931640f67cab3e3a16F4dC": "mUSDT",
        "0x420000000000000000000000000000000000000A": "WETH",
    }
    order = list(names.keys())
    for i, addr in enumerate(order, 1):
        raw = open(f"raw/reservedata_{i}.txt").read().strip()
        # strip outer parens
        body = raw[1:-1]
        # split top-level commas
        parts, depth, cur = [], 0, ""
        for ch in body:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            if ch == "," and depth == 0:
                parts.append(cur.strip()); cur = ""
            else:
                cur += ch
        parts.append(cur.strip())
        cfg = int(parts[0].split()[0])
        entry = {
            "idx": i - 1,
            "asset": addr,
            "name": names[addr],
            "configuration_raw": str(cfg),
            "config": decode(cfg),
            "liquidityIndex": parts[1].split()[0],
            "currentLiquidityRate": parts[2].split()[0],
            "variableBorrowIndex": parts[3].split()[0],
            "currentVariableBorrowRate": parts[4].split()[0],
            "currentStableBorrowRate": parts[5].split()[0],
            "lastUpdateTimestamp": parts[6].split()[0],
            "id": parts[7].split()[0],
            "aToken": parts[8],
            "stableDebtToken": parts[9],
            "variableDebtToken": parts[10],
            "interestRateStrategy": parts[11],
            "accruedToTreasury": parts[12].split()[0],
            "unbacked": parts[13].split()[0],
            "isolationModeTotalDebt": parts[14].split()[0],
        }
        reserves.append(entry)
    json.dump(reserves, open("raw/reserves_decoded.json", "w"), indent=1)
    for e in reserves:
        c = e["config"]
        print(f"[{e['idx']}] {e['name']:5s} {e['asset']}")
        print(f"    aToken={e['aToken']} vDebt={e['variableDebtToken']}")
        print(f"    LTV={c['LTV']} liqThr={c['liqThreshold']} liqBonus={c['liqBonus']} dec={c['decimals']} "
              f"active={c['active']} frozen={c['frozen']} borrow={c['borrowingEnabled']} stable={c['stableBorrowEnabled']} "
              f"paused={c['paused']} flash={c['flashLoanEnabled']} rf={c['reserveFactor']} caps={c['borrowCap']}/{c['supplyCap']} "
              f"liqFee={c['liqProtocolFee']} eMode={c['eModeCategory']} debtCeil={c['debtCeiling']}")
        print(f"    liqIdx={e['liquidityIndex']} varIdx={e['variableBorrowIndex']} lastUpdate={e['lastUpdateTimestamp']} "
              f"accruedToTreasury={e['accruedToTreasury']}")
