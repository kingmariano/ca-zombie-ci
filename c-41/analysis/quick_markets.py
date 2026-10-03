#!/usr/bin/env python3
"""Compact Ionic comptroller market reader (read-only) — essentials only, for the report.

Usage: python3 quick_markets.py <chain> <comptroller> [account] [--out FILE]
Chains: mode, base, op, lisk (RPC overridable via IONIC_RPC_URL env).
"""
import json
import os
import sys
import time

from rpc import RPC

CHAINS = {
    "mode": "https://mainnet.mode.network",
    "base": "https://mainnet.base.org",
    "op": "https://mainnet.optimism.io",
    "lisk": "https://rpc.api.lisk.com",
}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else None
    chain, comp = args[0], args[1]
    acct = args[2] if len(args) > 2 else None
    url = os.environ.get("IONIC_RPC_URL") or CHAINS[chain]
    r = RPC(url, batch_size=3)
    block = r.block_number()
    st = {"chain": chain, "comptroller": comp, "block": block,
          "ts_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

    mres = r.read(comp, "getAllMarkets()(address[])")
    markets = [m for m in mres if isinstance(m, str) and m.startswith("0x")] if isinstance(mres, (list, tuple)) else []
    st["markets_count"] = len(markets)
    st["globals"] = {}
    for sig in ["oracle()(address)", "admin()(address)", "pauseGuardian()(address)",
                "_mintGuardianPaused()(bool)", "_borrowGuardianPaused()(bool)",
                "transferGuardianPaused()(bool)", "seizeGuardianPaused()(bool)",
                "enforceWhitelist()(bool)", "closeFactorMantissa()(uint256)",
                "liquidationIncentiveMantissa()(uint256)"]:
        st["globals"][sig.split("(")[0]] = r.read(comp, sig)

    oracle = st["globals"].get("oracle")
    rows = []
    for m in markets:
        row = {"market": m}
        for sig in ["symbol()(string)", "underlying()(address)", "getCash()(uint256)",
                    "totalSupply()(uint256)", "totalBorrows()(uint256)",
                    "totalAdminFees()(uint256)", "totalIonicFees()(uint256)",
                    "exchangeRateCurrent()(uint256)"]:
            row[sig.split("(")[0]] = r.read(m, sig)
        for sig in ["mintGuardianPaused(address)(bool)", "borrowGuardianPaused(address)(bool)",
                    "markets(address)(bool,uint256)", "isDeprecated(address)(bool)"]:
            row[sig.split("(")[0]] = r.read(comp, sig, [m])
        if isinstance(oracle, str) and oracle.startswith("0x"):
            row["oracle_price"] = r.read(oracle, "getUnderlyingPrice(address)(uint256)", [m])
        if acct:
            row["acct_balance"] = r.read(m, "balanceOf(address)(uint256)", [acct])
            row["acct_borrows"] = r.read(m, "borrowBalanceCurrent(address)(uint256)", [acct])
        rows.append(row)
        print(f"  {row.get('symbol')} cash={row.get('getCash')} borrows={row.get('totalBorrows')} "
              f"mintPaused={row.get('mintGuardianPaused')} borrowPaused={row.get('borrowGuardianPaused')}",
              file=sys.stderr)
    st["markets"] = rows

    if acct:
        st["account"] = {
            "address": acct,
            "assets_in": r.read(comp, "getAssetsIn(address)(address[])", [acct]),
            "suppliers": r.read(comp, "suppliers(address)(bool)", [acct]),
            "borrowers": r.read(comp, "borrowers(address)(bool)", [acct]),
        }

    if out:
        json.dump(st, open(out, "w"), indent=1, default=str)
    print(json.dumps({"chain": chain, "block": block, "markets": len(markets)}, indent=1))


if __name__ == "__main__":
    main()
