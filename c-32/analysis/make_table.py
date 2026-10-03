#!/usr/bin/env python3
"""
Render c-32 analysis/market_table.md from out/*.json scan results.
Applies a small reference-price override map with explicit sources for tokens where
the DefiLlama reading was inconsistent (wrsETH) or missing (native GLMR/MOVR).
"""
import json, os, time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

# corrected reference prices (USD), 2026-10-03
REF = {
    "wrsETH": (2943.68, "GeckoTerminal DEX (Base)"),
    "wrsETH@optimism": (2872.79, "GeckoTerminal DEX (OP)"),
    "MAMO": (0.0075599, "GeckoTerminal DEX (Base)"),
    "GLMR": (0.008481, "DefiLlama"),
    "MOVR": (1.8826, "DefiLlama"),
    "xcKSM": (5.10, "CoinGecko KSM"),
    "ETH": (2680.10, "CoinGecko"),
    "WETH": (2680.10, "CoinGecko"),
    "ETH.wh": (2680.10, "CoinGecko"),
    "WBTC": (84629.24, "CoinGecko"),
    "WBTC.wh": (84629.24, "CoinGecko"),
    "USDC": (1.0, "stable"),
    "USDC.wh": (1.0, "stable"),
    "xcUSDC": (1.0, "stable"),
    "USDT": (1.0, "stable"),
    "xcUSDT": (1.0, "stable"),
    "USD\u20ae0": (1.0, "stable"),
    "BUSD": (1.0, "stable"),
    "BUSD.wh": (1.0, "stable"),
    "FRAX": (0.9923, "DefiLlama"),
    "xcDOT": (1.1655, "CoinGecko DOT"),
}

CHAINS = ["base", "optimism", "ethereum", "moonbeam", "moonriver"]


def main():
    lines = ["# C-32 Moonwell market/oracle table",
             "",
             f"Generated {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())} from `analysis/out/*.json` "
             "(on-chain reads; external refs as noted). All values USD per whole token.",
             ""]
    for ch in CHAINS:
        p = os.path.join(OUT, f"{ch}.json")
        if not os.path.exists(p):
            lines.append(f"## {ch}: scan missing\n")
            continue
        r = json.load(open(p))
        lines.append(f"## {ch} (chain id {r['chain_id']}, block-head scan {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime(r['scanned_at']))})")
        lines.append("")
        lines.append(f"Comptroller `{r['comptroller']}`, oracle `{r['oracle']}` "
                     f"(matches docs: {r.get('oracle_matches_docs')}), close factor {r.get('close_factor')}, "
                     f"liquidation incentive {r.get('liq_incentive')}, pauseGuardian `{r.get('pause_guardian')}`")
        lines.append("")
        lines.append("| market | underlying | oracle $ | external $ (source) | div % | CF | borrow cap | mint/borrow paused | oracle src | feed age | feed |")
        lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
        for m in r["markets"]:
            s = m.get("underlying_symbol") or ""
            key = f"{s}@{ch}" if f"{s}@{ch}" in REF else s
            if key in REF:
                ext, src = REF[key]
            else:
                ext, src = m.get("external_price_usd"), m.get("external_price_source") or "n/a"
            div = None
            if m.get("oracle_price_usd") and ext:
                div = (m["oracle_price_usd"] / ext - 1) * 100
            fi = m.get("feed_info") or {}
            age = f"{fi.get('age_sec',0)/3600:.1f}h" if fi and fi.get("age_sec") is not None else "-"
            lines.append(
                f"| {m.get('symbol')} | {s} | {m.get('oracle_price_usd')} | "
                f"{ext if ext is not None else 'n/a'} ({src}) | "
                f"{('%.3f' % div) if div is not None else 'n/a'} | {m.get('collateral_factor')} | "
                f"{m.get('borrow_cap')} | {m.get('mint_paused')}/{m.get('borrow_paused')} | "
                f"{m.get('oracle_source')} | {age} | `{m.get('feed')}` |")
        lines.append("")
    with open(os.path.join(HERE, "market_table.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote analysis/market_table.md")


if __name__ == "__main__":
    main()
