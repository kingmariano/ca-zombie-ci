#!/usr/bin/env python3
"""Per-option detail dump for the legacy Carmine pools (evidence for the H-O numbers)."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enumerate_claims import LEGACY, get_options, option_len, get_supplies, terminal_prices, payout, DECIMALS
from sn import call, arr, u256, block_number

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "legacy-options-details.json")


def main():
    d = {"block": block_number(), "pools": {}}
    lps = arr(call(LEGACY, "get_all_lptoken_addresses"))
    for lpt in lps:
        n = option_len(LEGACY, lpt, False)
        opts = get_options(LEGACY, lpt, n, False)
        sup = get_supplies(LEGACY, lpt, opts, False)
        pool = call(LEGACY, "get_pool_definition_from_lptoken_address", [lpt])
        quote, base, otype = hex(pool[0]), hex(pool[1]), pool[2]
        prices = terminal_prices(LEGACY, opts, False, quote, base)
        rows = []
        for o, (tok, supply) in zip(opts, sup):
            T = prices.get(o["maturity"])
            row = {"side": o["side"], "maturity": o["maturity"], "strike_m64x61": o["strike"],
                   "strike": o["strike"] / 2 ** 61, "option_token": tok, "total_supply_raw": supply,
                   "terminal_price_m64x61": T if not isinstance(T, str) else None}
            if supply and not isinstance(T, str):
                # option-token supplies are always in BASE-token units (ETH/STRK/EKUBO/WBTC);
                # legacy pools are ETH-based only
                size = supply / 10 ** 18
                row["size_native"] = size
                row["terminal_price"] = T / 2 ** 61
                row["payout_native"] = payout(otype, o["side"], size, row["strike"], row["terminal_price"])
            rows.append(row)
        d["pools"][hex(lpt)] = {"quote": quote, "base": base, "option_type": otype, "n_options": n, "options": rows}
        print(f"{hex(lpt)[:14]} rows={len(rows)}", file=sys.stderr)
    json.dump(d, open(OUT, "w"), indent=1)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
