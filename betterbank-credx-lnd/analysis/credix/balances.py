#!/usr/bin/env python3
"""CrediX balances snapshot at one block. Read-only."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

SEL = {
    "symbol": "0x95d89b41",
    "name": "0x06fdde03",
    "decimals": "0x313ce567",
    "balanceOf": "0x70a08231",
    "totalSupply": "0x18160ddd",
    "scaledTotalSupply": "0xb1bf962d",
    "getReserveNormalizedIncome": "0xd15e0053",
    "getReserveNormalizedVariableDebt": "0x386497fd",
    "getUserAccountData": "0xbf92857c",
    "getUserEMode": "0xeddf1b79",
}

ZERO = "0x0000000000000000000000000000000000000000"


def call_many(to, datas, block):
    calls = [("eth_call", [{"to": to, "data": d}, block]) for d in datas]
    return batch(calls)


def dec_str(hexstr):
    if not isinstance(hexstr, str):
        return None
    try:
        h = hexstr[2:]
        if len(h) < 128:
            return None
        ln = int(h[64:128], 16)
        return bytes.fromhex(h[128:128 + ln * 2]).decode("utf-8", "replace")
    except Exception:
        return None


def pad_addr(a):
    return a[2:].lower().rjust(64, "0")


def main():
    enum = json.load(open(os.path.join(RAW, "enumeration.json")))
    block = int(rpc("eth_blockNumber", []), 16)
    # pin picked block for all reads
    out = {"block": block, "markets": {}, "native_balances": {}}

    for mname, m in enum["markets"].items():
        pool = m["pool"]
        entry = {"pool": pool, "reserves": []}
        for r in m["reserves"]:
            asset = r["asset"]
            rd = r["reserveData"]
            rec = {"asset": asset, "symbol": r["symbol"], "decimals": r["decimals"],
                   "aToken": rd["aTokenAddress"], "vToken": rd["variableDebtTokenAddress"],
                   "sToken": rd["stableDebtTokenAddress"],
                   "accruedToTreasury": rd["accruedToTreasury"], "unbacked": rd["unbacked"],
                   "isolationModeTotalDebt": rd["isolationModeTotalDebt"],
                   "configuration": rd["configuration"]}
            # pool underlying balance + normalized indexes
            res = batch([
                ("eth_call", [{"to": asset, "data": SEL["balanceOf"] + pad_addr(pool)}, hex(block)]),
                ("eth_call", [{"to": pool, "data": SEL["getReserveNormalizedIncome"] + pad_addr(asset)}, hex(block)]),
                ("eth_call", [{"to": pool, "data": SEL["getReserveNormalizedVariableDebt"] + pad_addr(asset)}, hex(block)]),
            ])
            rec["underlying_pool_balance"] = dec_u(res[0]) if isinstance(res[0], str) else res[0]
            rec["liquidityIndex"] = dec_u(res[1]) if isinstance(res[1], str) else res[1]
            rec["variableBorrowIndex"] = dec_u(res[2]) if isinstance(res[2], str) else res[2]

            # aToken / debt token state
            for key, tok in (("aToken", rd["aTokenAddress"]), ("vToken", rd["variableDebtTokenAddress"]),
                             ("sToken", rd["stableDebtTokenAddress"])):
                if not tok or tok == ZERO:
                    rec[key + "_zero"] = True
                    continue
                tdec = call_many(tok, [SEL["decimals"], SEL["totalSupply"], SEL["scaledTotalSupply"],
                                       SEL["balanceOf"] + pad_addr(pool), SEL["balanceOf"] + pad_addr(pool)], hex(block))
                rec[key + "_decimals"] = dec_u(tdec[0]) if isinstance(tdec[0], str) else None
                rec[key + "_totalSupply"] = dec_u(tdec[1]) if isinstance(tdec[1], str) else tdec[1]
                rec[key + "_scaledTotalSupply"] = dec_u(tdec[2]) if isinstance(tdec[2], str) else tdec[2]
                rec[key + "_pool_balance"] = dec_u(tdec[3]) if isinstance(tdec[3], str) else tdec[3]
            entry["reserves"].append(rec)

        # user account data for key addresses
        entry["accounts"] = {}
        for who in ("0xF321683831Be16eeD74dfA58b02a37483cEC662e",
                    "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
                    "0x3d0c177E035C30bb8681e5859EB98d114b48b935",
                    "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F"):
            uad = batch([
                ("eth_call", [{"to": pool, "data": SEL["getUserAccountData"] + pad_addr(who)}, hex(block)]),
                ("eth_call", [{"to": pool, "data": SEL["getUserEMode"] + pad_addr(who)}, hex(block)]),
            ])
            if isinstance(uad[0], str) and len(uad[0]) >= 2 + 64 * 6:
                h = uad[0][2:]
                w = [int(h[i * 64:(i + 1) * 64], 16) for i in range(6)]
                entry["accounts"][who] = {
                    "totalCollateralBase": w[0], "totalDebtBase": w[1],
                    "availableBorrowsBase": w[2], "currentLiquidationThreshold": w[3],
                    "ltv": w[4], "healthFactor": w[5],
                    "healthFactor_1e18": w[5] / 1e18,
                }
            else:
                entry["accounts"][who] = {"error": uad[0]}
        out["markets"][mname] = entry

    # native balances of a broad set of contracts
    addrs = set()
    for m in enum["markets"].values():
        for k in ("provider", "pool", "getPoolConfigurator", "getPriceOracle", "getACLManager",
                  "getACLAdmin", "getPoolDataProvider", "owner"):
            a = m.get(k)
            if a and a != "0x" and a.lower() != ZERO:
                addrs.add(a.lower())
        for r in m["reserves"]:
            rd = r["reserveData"]
            for k in ("aTokenAddress", "variableDebtTokenAddress", "stableDebtTokenAddress",
                      "interestRateStrategyAddress"):
                if rd.get(k) and rd[k].lower() != ZERO:
                    addrs.add(rd[k].lower())
            addrs.add(r["asset"].lower())
    for eoa in ("0xF321683831Be16eeD74dfA58b02a37483cEC662e", "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf"):
        addrs.add(eoa.lower())
    calls = [("eth_getBalance", [a, hex(block)]) for a in sorted(addrs)]
    res = batch(calls)
    for a, v in zip(sorted(addrs), res):
        out["native_balances"][a] = dec_u(v) if isinstance(v, str) else v

    with open(os.path.join(RAW, "balances.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("block", block, "saved balances.json")


if __name__ == "__main__":
    main()
