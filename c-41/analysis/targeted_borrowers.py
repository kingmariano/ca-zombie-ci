#!/usr/bin/env python3
"""Targeted Mode-A liquidation check: top historical borrowers per debt market ->
current borrow -> account liquidity -> shortfall list. Read-only."""
import json
import time

import requests
from eth_utils import keccak, to_checksum_address as ck

U = "https://mainnet.mode.network"
COMP = "0xFB3323E24743Caf4ADD0fDCCFB268565c0685556"
DEPOSITOR = "0x9E34d89C013Da3BF65fc02b59B6F27D710850430"


def rpc(method, params, tries=5):
    for _ in range(tries):
        try:
            r = requests.post(U, json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=120).json()
            if "result" in r:
                return r["result"]
            if "rate" in str(r.get("error", "")).lower():
                time.sleep(3)
                continue
            return None
        except Exception:  # noqa: BLE001
            time.sleep(3)
    return None


def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])


def sig(s):
    return "0x" + keccak(text=s)[:4].hex()


def main():
    ev = json.load(open("mode_a_borrow_events.json"))
    symbols, debt = ev["symbols"], ev["debt"]
    rows = []
    for m, agg in debt.items():
        if not agg:
            continue
        top = sorted(agg.items(), key=lambda x: -x[1])[:25]
        for who, hist in top:
            bal = call(m, sig("borrowBalanceCurrent(address)") + "000000000000000000000000" + who[2:])
            if not bal:
                continue
            v = int(bal, 16)
            if v <= 0:
                continue
            # account liquidity
            res = call(COMP, sig("getAccountLiquidity(address)") + "000000000000000000000000" + who[2:])
            liq = None
            if res:
                err, liquidity, shortfall = (int(res[i : i + 64], 16) for i in (2, 66, 130))
                liq = {"err": err, "liquidity": liquidity, "shortfall": shortfall}
            # assets
            ares = call(COMP, sig("getAssetsIn(address)") + "000000000000000000000000" + who[2:])
            n_assets = 0
            if ares:
                n_assets = int(ares[66:130], 16)
            rows.append({"market": symbols[m], "market_addr": m, "borrower": who,
                         "current_borrow": v, "liq": liq, "n_assets": n_assets})
            print(f"{symbols[m]:<14} {who} borrow={v} liq={liq} assets={n_assets}", flush=True)
    json.dump(rows, open("mode_a_top_borrowers.json", "w"), indent=1)
    short = [r for r in rows if r["liq"] and r["liq"]["shortfall"] > 0]
    print("SHORTFALL COUNT:", len(short))
    for r in short:
        print("SHORT:", json.dumps(r))


if __name__ == "__main__":
    main()
