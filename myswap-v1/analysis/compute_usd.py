#!/usr/bin/env python3
"""Compute USD values for the H-10 mySwap V1 (and sibling CL) measured balances.

Reads live_state.json (from verify_live.py), fetches DefiLlama prices with urllib (stdlib),
falls back to recorded prices if the price API is unreachable.

Usage: compute_usd.py [live_state.json] [usd_summary.json]
"""
import json
import os
import sys
import urllib.request

# recorded 2026-10-03, source coins.llama.fi (timestamp 1791046310)
FALLBACK_PRICES = {
    "ETH": 2680.90, "USDC": 1.00, "USDT": 1.00, "DAI": 1.00, "WBTC": 84824.71,
    "wstETH": 3338.58, "LORDS": 0.00262656, "STRK": 0.0503459, "LUSD": 1.00731,
    "RETH": 3137.02,
}
DECIMALS = {"ETH": 18, "USDC": 6, "USDT": 6, "DAI": 18, "WBTC": 8, "wstETH": 18,
            "LORDS": 18, "STRK": 18, "LUSD": 18, "RETH": 18}
TOKEN_ADDR = {
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "DAI": "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "wstETH": "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "LORDS": "0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "LUSD": "0x070a76fd48ca0ef910631754d77dd822147fe98a569b826ec85e3c33fde586ac",
    "RETH": "0x0319111a5037cbec2b3e638cc34a3474e2d2608299f3e62866e9cc683208c610",
}


def fetch_prices():
    coins = ",".join(f"starknet:{a}" for a in TOKEN_ADDR.values())
    url = "https://coins.llama.fi/prices/current/" + coins
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            j = json.loads(r.read().decode())
        out = {}
        for name, addr in TOKEN_ADDR.items():
            c = j["coins"].get(f"starknet:{addr}")
            if c:
                out[name] = c["price"]
        return out, j.get("coins", {}).get(f"starknet:{TOKEN_ADDR['ETH']}", {}).get("timestamp")
    except Exception as e:
        return {}, f"price fetch failed: {e}"


def val(raw, name, prices):
    if raw is None or isinstance(raw, str) and raw.startswith("ERR"):
        return 0.0
    amount = int(raw) / (10 ** DECIMALS[name])
    return amount * prices.get(name, FALLBACK_PRICES[name])


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    live_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(base, "..", "ci-out", "live_state.json")
    out_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(base, "..", "ci-out", "usd_summary.json")
    with open(live_path) as f:
        live = json.load(f)

    prices, ts = fetch_prices()
    used_fallback = False
    if not prices:
        prices = dict(FALLBACK_PRICES)
        used_fallback = True
    prices = {**FALLBACK_PRICES, **prices}

    def breakdown(balances, label):
        rows = []
        total = 0.0
        for name in DECIMALS:
            raw = balances.get(name)
            v = val(raw, name, prices)
            total += v
            rows.append({"token": name, "raw": raw, "amount": (int(raw) / 10 ** DECIMALS[name]) if raw and not str(raw).startswith("ERR") else 0,
                         "usd": round(v, 4)})
        return {"label": label, "rows": rows, "total_usd": round(total, 2)}

    out = {
        "latest_block": live.get("latest_block"),
        "prices_used": prices,
        "prices_source": "coins.llama.fi" if not used_fallback else "fallback-recorded-2026-10-03",
        "price_timestamp": ts,
        "v1_legacy_dust": breakdown(live["current_state"]["balances"], "V1 MySwapLegacy residual dust"),
        "cl_singleton_residual": breakdown(live["current_state"]["cl_singleton_balances"], "mySwap CL singleton residual"),
        "merkle_distributor": breakdown(live["current_state"]["merkle_distributor"].get("balances", {}), "mySwap UI Merkle distributor"),
    }
    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
    for k in ["v1_legacy_dust", "cl_singleton_residual", "merkle_distributor"]:
        print(f"{k}: ${out[k]['total_usd']}")
    print("wrote", out_path)


if __name__ == "__main__":
    main()
