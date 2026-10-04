#!/usr/bin/env python3
"""Liquidity held by aToken/debt-token contracts (Aave V3 holds underlying at aToken)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
SEL_BAL = "0x70a08231"
ZERO = "0x0000000000000000000000000000000000000000"


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    enum = json.load(open(os.path.join(RAW, "enumeration.json")))
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "markets": {}}
    for mname, m in enum["markets"].items():
        entry = {"pool": m["pool"], "reserves": {}}
        for r in m["reserves"]:
            a = r["asset"]
            rd = r["reserveData"]
            rec = {"symbol": r["symbol"], "decimals": r["decimals"],
                   "aToken": rd["aTokenAddress"], "vToken": rd["variableDebtTokenAddress"],
                   "sToken": rd["stableDebtTokenAddress"]}
            calls, keys = [], []
            for k, tok in (("aToken", rd["aTokenAddress"]), ("vToken", rd["variableDebtTokenAddress"]),
                           ("sToken", rd["stableDebtTokenAddress"])):
                if tok and tok.lower() != ZERO:
                    calls.append(("eth_call", [{"to": a, "data": SEL_BAL + pad_a(tok)}, hex(block)]))
                    keys.append(k)
            # also check pool itself + provider + configurator of same market for stray underlying
            pools_extra = [m["pool"], m["provider"], m.get("getPoolConfigurator"),
                           m.get("getACLManager"), m.get("getPoolDataProvider"), m.get("getPriceOracle")]
            for x in pools_extra:
                if x and x.lower() != ZERO:
                    calls.append(("eth_call", [{"to": a, "data": SEL_BAL + pad_a(x)}, hex(block)]))
                    keys.append("at:" + x.lower())
            res = batch(calls)
            for k, v in zip(keys, res):
                rec[k] = dec_u(v) if isinstance(v, str) else v
            entry["reserves"][r["symbol"] + "@" + a[:8]] = rec
        out["markets"][mname] = entry
    with open(os.path.join(RAW, "liquidity_at_atokens.json"), "w") as f:
        json.dump(out, f, indent=1)

    for mname, e in out["markets"].items():
        print(f"===== {mname} =====")
        for rk, rec in e["reserves"].items():
            dec = rec["decimals"] or 18
            at = rec.get("aToken", 0) or 0
            vt = rec.get("vToken", 0) or 0
            st = rec.get("sToken", 0) or 0
            extr = {k: v for k, v in rec.items() if k.startswith("at:") and isinstance(v, int) and v}
            print(f"  {rec['symbol']:<8} aToken_holds={at/10**dec:>18.6f} vToken_holds={vt/10**dec:>14.6f} "
                  f"sToken_holds={st/10**dec:>12.6f} stray={extr if extr else ''}")


if __name__ == "__main__":
    main()
