#!/usr/bin/env python3
"""Quantify drainable value per pair for the buggy skim class."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "analysis")
BUG = "0xaef408ec73c83edbc42d00af164ae8073404aa665b9895041c705c871809f9"

def main():
    pairs = {json.loads(l)["pair"]: json.loads(l) for l in open(os.path.join(OUT, "pairs_raw.jsonl"))}
    bals = {json.loads(l)["pair"]: json.loads(l) for l in open(os.path.join(OUT, "pair_balances.jsonl"))}
    prices = json.load(open(os.path.join(OUT, "token_prices.json")))
    meta = json.load(open(os.path.join(OUT, "factory_state.json")))
    chs = meta["pair_class_hashes"]
    vaults = meta["vaults"]

    def price(tok):
        k = f"starknet:{tok}"
        return prices.get(k, {}).get("price")

    rows = []
    for p, b in bals.items():
        if chs.get(p) != BUG:
            continue
        snap = pairs[p]
        d0 = int(snap["decimal0"]); d1 = int(snap["decimal1"])
        r0, r1, b0, b1 = b["r0"], b["r1"], b["b0"], b["b1"]
        # buggy skim: transfer amount0 = b0-r0 of token0 (must be >=0), amount1 = b0-r1 of token1 (must be <= b1)
        # attacker donates d token0 (returned) to raise b0 to b0+d; max drain of token1 = b1 if b0+d-r1 <= b1
        drainable_raw = b1 if b0 <= r1 + b1 else 0
        need_donation = max(0, (r1 + b1) - b0)
        p0, p1 = price(snap["token0"]), price(snap["token1"])
        v1 = drainable_raw / d1 * p1 if p1 else None
        rows.append({
            "pair": p, "token0": snap["token0"], "token1": snap["token1"],
            "dec0": d0, "dec1": d1, "r0": r0, "r1": r1, "b0": b0, "b1": b1,
            "stable": snap["is_stable"], "fee_tier": snap["fee_tier"],
            "drainable_raw": str(drainable_raw), "need_donation_raw": str(need_donation),
            "price0": p0, "price1": p1, "drain_usd": round(v1, 2) if v1 is not None else None,
            "vault": vaults.get(p),
        })
    rows.sort(key=lambda r: (r["drain_usd"] is not None, r["drain_usd"] or 0), reverse=True)
    with open(os.path.join(OUT, "drainable_buggy_class.json"), "w") as fh:
        json.dump(rows, fh, indent=1)

    priced = [r for r in rows if r["drain_usd"] is not None]
    unpriced = [r for r in rows if r["drain_usd"] is None and int(r["drainable_raw"]) > 0]
    zero = [r for r in rows if int(r["drainable_raw"]) == 0]
    print(f"buggy-class pairs: {len(rows)} | drainable>0: {len(rows)-len(zero)} | zero (r0>2r1): {len(zero)}")
    print(f"priced drainable: {len(priced)} | unpriced with drainable>0: {len(unpriced)}")
    print(f"TOTAL priced drainable USD: {sum(r['drain_usd'] for r in priced):.2f}")
    print("\nTop 20 by USD:")
    for r in priced[:20]:
        print(f"  {r['pair'][:14]} drain={int(r['drainable_raw'])/r['dec1']:.6g} tok1 usd=${r['drain_usd']:>10.2f} need_d={int(r['need_donation_raw'])/r['dec0']:.6g} tok0 stable={r['stable']} fee={r['fee_tier']}")
    print("\nUnpriced drainable pairs (raw token1 amounts):")
    for r in unpriced[:30]:
        print(f"  {r['pair'][:14]} tok1={r['token1'][:14]} drain_raw={r['drainable_raw']} need_d_raw={r['need_donation_raw']}")
    return rows

if __name__ == "__main__":
    main()
