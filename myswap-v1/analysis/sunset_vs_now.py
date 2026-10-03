#!/usr/bin/env python3
"""Compute sunset (2025-05-13) reserves vs current dust for mySwap V1 -> distributed amounts + USD.

Inputs: analysis/live_state.json (sunset pools + current balances). Read-only.
Writes analysis/sunset_distribution.json.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compute_usd import FALLBACK_PRICES, DECIMALS  # noqa

BASE = os.path.dirname(os.path.abspath(__file__))
live = json.load(open(os.path.join(BASE, "live_state.json")))

# sum sunset reserves per token (pool reserves == core holdings at sunset)
sunset = {}
for p in live["sunset_state"]["pools"]:
    for tok, amt in ((p["token_a"], int(p["reserves_a"])), (p["token_b"], int(p["reserves_b"]))):
        sunset[tok] = sunset.get(tok, 0) + amt

ADDR2NAME = {
    "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7": "ETH",
    "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8": "USDC",
    "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8": "USDT",
    "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3": "DAI",
    "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac": "WBTC",
    "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2": "wstETH",
    "0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49": "LORDS",
}
cur = live["current_state"]["balances"]

rows = []
total_sunset_usd = 0.0
total_dust_usd = 0.0
for addr, amt in sunset.items():
    name = ADDR2NAME.get(addr.lower(), addr)
    dust = int(cur.get(name, 0)) if name in cur else 0
    distributed = amt - dust
    usd = distributed / 10 ** DECIMALS[name] * FALLBACK_PRICES[name]
    dust_usd = dust / 10 ** DECIMALS[name] * FALLBACK_PRICES[name]
    total_sunset_usd += amt / 10 ** DECIMALS[name] * FALLBACK_PRICES[name]
    total_dust_usd += dust_usd
    rows.append({
        "token": name, "sunset_raw": str(amt), "dust_raw": str(dust), "distributed_raw": str(distributed),
        "distributed_usd_at_2026_10_03": round(usd, 2), "dust_usd": round(dust_usd, 4),
    })

out = {
    "sunset_block": live["sunset_state"]["block"],
    "upgrade_block": 1397399,
    "rows": rows,
    "total_sunset_usd_at_2026_10_03": round(total_sunset_usd, 2),
    "total_distributed_usd_at_2026_10_03": round(total_sunset_usd - total_dust_usd, 2),
    "total_dust_usd": round(total_dust_usd, 2),
    "note": "Sunset reserves reconstructed by summing the 8 pools' reserves at block 1,397,398; "
            "prices are 2026-10-03 DefiLlama values (ETH 2680.90 etc.), so the USD total is the value "
            "of the distributed tokens today, not the May-2025 value. DefiLlama's last-known V1 TVL "
            "(~$0.61M, stale 506d) matches this same set of tokens.",
}
with open(os.path.join(BASE, "sunset_distribution.json"), "w") as f:
    json.dump(out, f, indent=1)
for r in rows:
    print(f"{r['token']:7s} distributed {r['distributed_raw']:>30s}  (${r['distributed_usd_at_2026_10_03']})")
print("TOTAL sunset value (today's prices): $", out["total_sunset_usd_at_2026_10_03"])
print("TOTAL dust: $", out["total_dust_usd"])
