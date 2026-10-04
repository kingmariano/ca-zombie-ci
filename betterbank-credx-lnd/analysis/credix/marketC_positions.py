#!/usr/bin/env python3
"""Market C: borrower position, health, flags, prices, liquidation viability."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

POOL = "0x12144c9b3fdCc1E40083280C3FE28BB568814A91"
DP = "0x8c6a79f47ce3febe4e571747af39fb305a6070e8"
ORACLE = "0xfae2038b7b4a25aca1c3fc0ff8c7c19d09a78806"
BORROWER = "0xeae43e21a658b41d741139854cafde9ef7a580ab"
ASSETS = {
    "USDC": "0x29219dd400f2Bf60E5a23d13Be72B486D4038894",
    "scUSD": "0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE",
    "YT-scUSD": "0xd2901D474b351bC6eE7b119f9c920863B0F781b2",
}
TOKENS = {
    "aciUSDC": "0xacd8c3e8fd67142a677b35aabe3f21e3779b58c7",
    "aciscUSD": "0xb1eebda7f7ec7bd53d1f2d12b414129f89f24aaf",
    "aciYT-scUSD": "0xe192d8700fbdc8aae23b5881c3ef55b90de69373",
    "variableDebtciUSDC": "0xab7655f4efbca6ce716323fcbefa9aee8b74bfbf",
    "variableDebtciscUSD": "0x3fa6fa594f1cd89636a88f4d3b79977dd54d07d8",
    "variableDebtciYT-scUSD": "0x81f5b707cdbb7b80c9aaa7af2e042b0a9af78ad5",
}
SUBJECTS = {
    "borrower": BORROWER,
    "safeB": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    "admin_0x0dd0": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
    "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
    "deployer": "0xc7461891c88f6a609d9149d2826704bd178a80de",
    "safeOwner2": "0x75eF5d635388d7C97425596CE50c11844234128B",
}


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block}

    # account data
    out["accounts"] = {}
    for name, a in SUBJECTS.items():
        v = rpc("eth_call", [{"to": POOL, "data": "0xbf92857c" + pad_a(a)}, hex(block)])
        if isinstance(v, str) and len(v) >= 2 + 64 * 6:
            h = v[2:]
            w = [int(h[i * 64:(i + 1) * 64], 16) for i in range(6)]
            out["accounts"][name] = {"address": a, "totalCollateralBase": w[0], "totalDebtBase": w[1],
                                     "availableBorrowsBase": w[2], "liqThreshold": w[3], "ltv": w[4],
                                     "healthFactor": w[5], "hf_1e18": w[5] / 1e18}
        else:
            out["accounts"][name] = {"address": a, "error": v}

    # token balances for subjects
    out["tokens"] = {}
    for tname, tok in TOKENS.items():
        rec = {"address": tok}
        calls = [("eth_call", [{"to": tok, "data": "0x18160ddd"}, hex(block)])]
        keys = ["totalSupply"]
        for sname, s in SUBJECTS.items():
            calls.append(("eth_call", [{"to": tok, "data": "0x70a08231" + pad_a(s)}, hex(block)]))
            keys.append(sname)
        res = batch(calls)
        for k, v in zip(keys, res):
            rec[k] = dec_u(v) if isinstance(v, str) else v
        out["tokens"][tname] = rec

    # reserve configs + prices
    out["reserves"] = {}
    for sym, asset in ASSETS.items():
        cfg = rpc("eth_call", [{"to": DP, "data": "0x3e150141" + pad_a(asset)}, hex(block)])
        price = rpc("eth_call", [{"to": ORACLE, "data": "0xb3596f07" + pad_a(asset)}, hex(block)])
        rec = {"asset": asset}
        if isinstance(cfg, str) and len(cfg) >= 2 + 64 * 10:
            h = cfg[2:]
            w = [int(h[i * 64:(i + 1) * 64], 16) for i in range(10)]
            rec["config"] = {"decimals": w[0], "ltv": w[1], "liqThreshold": w[2], "liqBonus": w[3],
                             "reserveFactor": w[4], "collateralEnabled": bool(w[5]),
                             "borrowingEnabled": bool(w[6]), "stableBorrowEnabled": bool(w[7]),
                             "isActive": bool(w[8]), "isFrozen": bool(w[9])}
        else:
            rec["config"] = {"error": cfg}
        rec["price_1e8"] = dec_u(price) if isinstance(price, str) else price
        out["reserves"][sym] = rec

    # eMode + pause checks
    out["paused_configB"] = rpc("eth_call", [{"to": DP, "data": "0x3e150141" + pad_a(ASSETS["USDC"])}, hex(block)])

    json.dump(out, open(os.path.join(RAW, "marketC_positions.json"), "w"), indent=1)
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
