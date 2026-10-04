#!/usr/bin/env python3
"""Price the nonzero Francium-controlled balances via DefiLlama coins API."""
import json, sys, os, urllib.request, time

OUT = os.path.dirname(os.path.abspath(__file__))

def fetch_prices(mints):
    out = {}
    for i in range(0, len(mints), 40):
        chunk = mints[i:i+40]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"solana:{m}" for m in chunk)
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=40) as r:
                d = json.loads(r.read())
            out.update(d.get("coins", {}))
        except Exception as e:
            print("price fetch err", e, file=sys.stderr)
        time.sleep(0.5)
    return out

def main():
    bal = json.load(open(os.path.join(OUT, "balances.json")))
    rows = [r for r in bal["rows"] if r.get("amount")]
    # classify roles
    def cat(r):
        roles = r["roles"]
        for role in roles:
            leaf = role.split(":")[-1]
            if leaf in ("liquiditySupplyPubkey",):
                return "reserve_liquidity"
            if leaf in ("tknAccount0", "tknAccount1"):
                return "strategy_token"
            if leaf in ("lpAccount", "lpTknAccount"):
                return "strategy_lp"
            if leaf == "staked_token_account":
                return "farm_staked"
            if leaf in ("rewards_token_account", "rewards_token_account_b"):
                return "farm_rewards"
            if leaf in ("liquidityFeeReceiver",):
                return "reserve_fee"
        return "other"
    mints = sorted({r["mint"] for r in rows})
    prices = fetch_prices(mints)
    json.dump(prices, open(os.path.join(OUT, "prices.json"), "w"), indent=1)
    # aggregate
    agg = {}
    unknown = set()
    for r in rows:
        m = r["mint"]
        p = prices.get(f"solana:{m}", {}).get("price")
        ui = r["amount"] / 10 ** r["decimals"]
        c = cat(r)
        key = (c, m, r["decimals"])
        a = agg.setdefault(key, {"ui": 0.0, "usd": 0.0, "price": p, "accounts": 0})
        a["ui"] += ui
        a["accounts"] += 1
        if p is not None:
            a["usd"] += ui * p
        else:
            unknown.add(m)
    total = 0.0
    print(f"{'category':18s} {'ui':>22s} {'usd':>16s}  mint")
    for (c, m, dec), a in sorted(agg.items(), key=lambda kv: -(kv[1]["usd"] if kv[1]["price"] else 0)):
        usd = f'{a["usd"]:,.2f}' if a["price"] is not None else "n/a"
        if a["price"] is not None:
            total += a["usd"]
        print(f"{c:18s} {a['ui']:>22.6f} {usd:>16s}  {m}")
    print("-" * 80)
    print(f"TOTAL PRICED (all categories, includes LP shares priced by DefiLlama if any): ${total:,.2f}")
    print("unpriced mints:", len(unknown))

if __name__ == "__main__":
    main()
