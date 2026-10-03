#!/usr/bin/env python3
"""
Quantify liquidation extraction from enumerate_positions.py output.

For each shortfall account, greedily allocate liquidation capacity:
  repay_d <= close_factor * borrow[d]        (protocol limit, 50%)
  seize_c = repay_value_oracle * (1+liq) / P_oracle(c) <= balance[c]
  profit  = repay_d * P_ext(d) * ... -> seize_c * P_ext(c) - repay_d * P_ext(d)

External prices (2026-10-03, sources: CoinGecko/DefiLlama, analysis/out/*.json).
Usage: python3 quantify.py <chain> <positions.json> <scan.json>
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# External USD reference prices per underlying symbol (Oct 3, 2026)
EXT = {
    "xcDOT": 1.1655, "DOT": 1.17,
    "WETH": 2680.10, "ETH": 2680.10, "ETH.wh": 2680.10,
    "WBTC": 84629.24, "WBTC.wh": 84629.24,
    "USDC": 1.0, "USDC.wh": 1.0, "xcUSDC": 1.0,
    "USDT": 1.0, "xcUSDT": 1.0, "USD₮0": 1.0,
    "FRAX": 0.9923, "BUSD": 1.0, "BUSD.wh": 1.0,
    "GLMR": 0.008481, "xcKSM": 5.10, "KSM": 5.10, "MOVR": 1.8826,
}


def u(h):
    return int(h, 16) if isinstance(h, str) and h.startswith("0x") else h


def main():
    chain, pos_path, scan_path = sys.argv[1], sys.argv[2], sys.argv[3]
    pos = json.load(open(pos_path))
    scan = json.load(open(scan_path))
    close = pos["close_factor"] or 0.5
    liq = (pos["liquidation_incentive"] or 1.1) - 1  # 0.1
    markets = pos["markets"]
    # oracle prices normalized to USD/whole token
    orc = {}
    for m, md in markets.items():
        dec = md["decimals"]
        raw = md.get("oracle_price")
        orc[m] = (raw / 10 ** (36 - dec)) if (raw and dec is not None) else None
    sy = {m: md["underlying_symbol"] for m, md in markets.items()}
    ext = {}
    for m in markets:
        s = sy[m]
        ext[m] = EXT.get(s)
    print(f"# {chain}: close_factor={close} liq_incentive={liq} markets={len(markets)}")
    print(f"# shortfall accounts: {len(pos['shortfall_accounts'])}")

    total_repay_oracle = 0.0
    total_profit = 0.0
    per_coll = {}
    per_acct = []
    skipped_no_price = set()
    details = pos["details"]
    for acct in pos["shortfall_accounts"]:
        d = details.get(acct)
        if not d:
            continue
        # collateral remaining in oracle USD (underlying units via balanceOfUnderlying)
        coll = {}
        cu = d.get("collaterals_underlying") or {}
        for m, bal in cu.items():
            if orc.get(m) and ext.get(m):
                coll[m] = int(bal) / 10 ** markets[m]["decimals"] * orc[m]
        if not coll:
            # fallback (should not happen)
            for m, bal in d["collaterals"].items():
                if orc.get(m) and ext.get(m):
                    coll[m] = bal / 10 ** markets[m]["decimals"] * orc[m]
        debt = {}
        for m, bb in d["borrows"].items():
            if orc.get(m) and ext.get(m):
                debt[m] = bb / 10 ** markets[m]["decimals"] * orc[m] * close
            else:
                skipped_no_price.add(sy.get(m))
        if not coll or not debt:
            continue
        # order debts by real-cost ratio benefit (prefer debts whose ext/oracle is low)
        profit_acct = 0.0
        repay_acct = 0.0
        # collateral preference: highest ext/oracle discount
        coll_sorted = sorted(coll.items(), key=lambda kv: -(ext[kv[0]] / orc[kv[0]]))
        debt_sorted = sorted(debt.items(), key=lambda kv: (ext[kv[0]] / orc[kv[0]]))
        remaining = dict(coll_sorted)
        for dm, dcap in debt_sorted:
            rem = dcap
            for cm, cval in coll_sorted:
                if rem <= 0 or remaining.get(cm, 0) <= 0:
                    continue
                # seize value (oracle) available from this collateral
                seize_cap = remaining[cm]
                # repay oracle value needed to seize seize_cap: seize/(1+liq)
                repay_from_c = seize_cap / (1 + liq)
                use = min(rem, repay_from_c)
                if use <= 0:
                    continue
                seized_real = use * (1 + liq) * ext[cm] / orc[cm]
                cost_real = use * ext[dm] / orc[dm]
                p = seized_real - cost_real
                if p > 0:
                    profit_acct += p
                    total_profit += p
                    per_coll[cm] = per_coll.get(cm, 0.0) + p
                repay_acct += use
                total_repay_oracle += use
                remaining[cm] -= use * (1 + liq)
                rem -= use
        if repay_acct > 0:
            per_acct.append({"account": acct, "repay_oracle_usd": repay_acct, "profit_usd": profit_acct,
                             "shortfall": d["shortfall"] / 1e18})
    per_acct.sort(key=lambda x: -x["profit_usd"])
    print(f"\nTOTAL repay capacity (oracle USD): ${total_repay_oracle:,.2f}")
    print(f"TOTAL estimated profit at external prices: ${total_profit:,.2f}")
    if skipped_no_price:
        print("skipped symbols with no external price:", skipped_no_price)
    print("\nprofit by seized collateral market:")
    for m, p in sorted(per_coll.items(), key=lambda kv: -kv[1]):
        print(f"  {markets[m]['symbol']:>10} ({sy[m]}): ${p:,.2f}")
    print("\nTop 25 accounts:")
    for r in per_acct[:25]:
        print(f"  {r['account']} profit=${r['profit_usd']:,.2f} repay(oracle)=${r['repay_oracle_usd']:,.2f} shortfall=${r['shortfall']:,.2f}")
    out = {"chain": chain, "total_repay_oracle_usd": total_repay_oracle, "total_profit_usd": total_profit,
           "per_collateral": {markets[m]["symbol"]: p for m, p in per_coll.items()},
           "accounts": per_acct, "latest_block": pos["latest_block"]}
    with open(os.path.join(HERE, "out", f"{chain}_liquidation_estimate.json"), "w") as f:
        json.dump(out, f, indent=1)


if __name__ == "__main__":
    main()
