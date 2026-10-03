#!/usr/bin/env python3
"""Compute extractable liquidation profit for all shortfall accounts from subgraph positions."""
import json
import urllib.request

SG = "https://graph-v2.cronoslabs.com/subgraphs/name/tectonic/tectonic-main"


def gql(query, variables=None, retries=4):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(SG, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.loads(r.read())
            if "errors" in out:
                last = out["errors"]
                continue
            return out["data"]
        except Exception as e:
            last = str(e)
    raise RuntimeError(last)


short = json.load(open("shortfall_accounts.json"))
d = json.load(open("subgraph_borrowers.json"))
markets = {m["id"].lower(): m for m in d["markets"]}
accts = list(short.keys())
print(f"shortfall accounts: {len(accts)}")

positions = {}
CH = 500
for i in range(0, len(accts), CH):
    chunk = [a.lower() for a in accts[i:i + CH]]
    q = """query($ids:[String!]){ accountTTokens(first:1000, where:{account_in:$ids}) {
      id storedBorrowBalance tTokenBalance enteredMarket account{id} market{id symbol underlyingSymbol underlyingDecimals exchangeRate collateralFactor underlyingPriceUSD} } }"""
    rows = gql(q, {"ids": chunk})["accountTTokens"]
    for r in rows:
        positions.setdefault(r["account"]["id"].lower(), []).append(r)
    print(f"  chunk {i//CH}: rows={len(rows)}", flush=True)

json.dump(positions, open("shortfall_positions.json", "w"), indent=1)

# real prices USD (from DefiLlama / DEX)
REAL = {
    "USDC": 0.9999967, "USDT": 0.999918, "DAI": 0.99994, "TUSD": 0.99925, "USC": 1.0,
    "CRO": 0.06614218, "WBTC": 84592.60, "WETH": 2680.21, "TONIC": 8.942e-9,
    "VVS": 1.0769e-6, "XRP": 1.48327, "LTC": 68.6797, "ADA": 0.244304, "ATOM": 1.67090,
    "LCRO": 0.0844839, "CDCBTC": 84006.12, "CDCETH": 2868.70,
}
PROTO_SEIZE_SHARE = 0.028


def analyze():
    rows_out = []
    total_profit = 0.0
    total_profit_skip_tonic = 0.0
    for a, pos in positions.items():
        cols = []
        debts = []
        for p in pos:
            m = p["market"]
            sym = m["symbol"].replace("t", "", 1) if m["symbol"].startswith("t") else m["symbol"]
            usym = m["underlyingSymbol"]
            tt = float(p["tTokenBalance"])
            sb = float(p["storedBorrowBalance"])
            if tt > 0:
                # collateral value USD at oracle
                cval = tt * float(m["exchangeRate"]) * float(m["underlyingPriceUSD"])
                cols.append({"market": m["symbol"], "usym": usym, "ttokens": tt, "oracle_usd": cval,
                             "cf": float(m["collateralFactor"]), "real_ratio": REAL.get(usym, 1.0) / float(m["underlyingPriceUSD"])})
            if sb > 0:
                dval = sb * float(m["underlyingPriceUSD"])
                debts.append({"market": m["symbol"], "usym": usym, "amount": sb, "oracle_usd": dval,
                              "real_ratio": REAL.get(usym, 1.0) / float(m["underlyingPriceUSD"])})
        best = None
        for dd in debts:
            for cc in cols:
                # repay up to 50% of debt (close factor), seize up to collateral/1.1
                repay_oracle = min(0.5 * dd["oracle_usd"], cc["oracle_usd"] / 1.1)
                if repay_oracle <= 0:
                    continue
                seize_oracle = repay_oracle * 1.1
                seize_net_real = seize_oracle * (1 - PROTO_SEIZE_SHARE) * cc["real_ratio"]
                repay_real = repay_oracle * dd["real_ratio"]
                profit = seize_net_real - repay_real
                if best is None or profit > best["profit"]:
                    best = {"debt": dd["market"], "coll": cc["market"], "repay_oracle": repay_oracle,
                            "seize_oracle": seize_oracle, "profit": profit,
                            "repay_real": repay_real, "seize_net_real": seize_net_real,
                            "debt_oracle_usd": dd["oracle_usd"], "coll_oracle_usd": cc["oracle_usd"]}
        if best and best["profit"] > 0:
            total_profit += best["profit"]
            if best["debt"] != "tTONIC":
                total_profit_skip_tonic += best["profit"]
            rows_out.append((a, best))
    rows_out.sort(key=lambda x: -x[1]["profit"])
    print(f"\naccounts with positive extractable profit: {len(rows_out)}")
    print(f"TOTAL extractable (best single pair per account): ${total_profit:,.2f}")
    print(f"  excluding TONIC-debt liquidations: ${total_profit_skip_tonic:,.2f}")
    print("\nTop 40:")
    for a, b in rows_out[:40]:
        print(f"{a} {b['debt']}->{b['coll']} repayOracle=${b['repay_oracle']:.2f} seizeOracle=${b['seize_oracle']:.2f} profit=${b['profit']:.2f} (debt=${b['debt_oracle_usd']:.2f} coll=${b['coll_oracle_usd']:.2f})")
    json.dump([{"account": a, **b} for a, b in rows_out], open("extractable_liquidations.json", "w"), indent=1)


if __name__ == "__main__":
    analyze()
