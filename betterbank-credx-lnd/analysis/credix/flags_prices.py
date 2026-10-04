#!/usr/bin/env python3
"""Reserve config flags + oracle prices + pool pause state."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

CFG = "0x3e150141"  # getReserveConfigurationData(address)
PRICE = "0xb3596f07"  # getAssetPrice(address)
SEL_PAUSED = "0x5c975abb"


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    enum = json.load(open(os.path.join(RAW, "enumeration.json")))
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "markets": {}}
    for mname, m in enum["markets"].items():
        dp = m["getPoolDataProvider"]
        oracle = m["getPriceOracle"]
        pool = m["pool"]
        entry = {"dataProvider": dp, "oracle": oracle, "reserves": {}, "paused_call": None}
        calls, meta = [], []
        for r in m["reserves"]:
            a = r["asset"]
            calls.append(("eth_call", [{"to": dp, "data": CFG + pad_a(a)}, hex(block)]))
            meta.append(("cfg", a))
            calls.append(("eth_call", [{"to": oracle, "data": PRICE + pad_a(a)}, hex(block)]))
            meta.append(("price", a))
        calls.append(("eth_call", [{"to": pool, "data": SEL_PAUSED}, hex(block)]))
        meta.append(("paused", pool))
        res = batch(calls)
        for (kind, a), v in zip(meta, res):
            sym = next((r["symbol"] for r in m["reserves"] if r["asset"] == a), a)
            if kind == "cfg":
                if isinstance(v, str) and len(v) >= 2 + 64 * 10:
                    h = v[2:]
                    w = [int(h[i * 64:(i + 1) * 64], 16) for i in range(10)]
                    entry["reserves"].setdefault(sym, {})["config"] = {
                        "decimals": w[0], "ltv": w[1], "liquidationThreshold": w[2],
                        "liquidationBonus": w[3], "reserveFactor": w[4],
                        "usageAsCollateralEnabled": bool(w[5]),
                        "borrowingEnabled": bool(w[6]),
                        "stableBorrowRateEnabled": bool(w[7]),
                        "isActive": bool(w[8]), "isFrozen": bool(w[9]),
                        "raw": v,
                    }
                else:
                    entry["reserves"].setdefault(sym, {})["config"] = {"error": v}
            elif kind == "price":
                entry["reserves"].setdefault(sym, {})["price_1e8"] = (
                    dec_u(v) if isinstance(v, str) else v)
            else:
                entry["paused_call"] = dec_u(v) if isinstance(v, str) else v
        out["markets"][mname] = entry

    with open(os.path.join(RAW, "flags_prices.json"), "w") as f:
        json.dump(out, f, indent=1)

    for mname, e in out["markets"].items():
        print(f"===== {mname} paused()={e['paused_call']} =====")
        for sym, d in e["reserves"].items():
            c = d.get("config", {})
            print(f"  {sym:<8} active={c.get('isActive')} frozen={c.get('isFrozen')} "
                  f"borrowing={c.get('borrowingEnabled')} ltv={c.get('ltv')} liqThr={c.get('liquidationThreshold')} "
                  f"liqBonus={c.get('liquidationBonus')} collateral={c.get('usageAsCollateralEnabled')} "
                  f"price_1e8={d.get('price_1e8')}")


if __name__ == "__main__":
    main()
