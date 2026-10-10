#!/usr/bin/env python3
"""Enumerate Carmine option-holder claims + LP claims on both AMMs (read-only).

Runs against a keyless public Starknet RPC (SN_RPC_URL env override supported; never store keys).
Writes JSON to stdout. Mirrors on-chain payout math via the contracts' own get_terminal_price views.

Usage:
  python3 enumerate_claims.py            # full run
  python3 enumerate_claims.py --pool legacy:0   # single pool (debug)
"""
import json, os, sys, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sn import call, call_batch, batch, block_number, u256, arr

LEGACY = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
NEW = "0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9"
SISTER = "0x1007d87af0a2b9b6199f5f09ab9c230f415470eeceb5a8b01590c51229da562"
TOKENS = {
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "EKUBO": "0x75afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
}
ADDR2SYM = {v: k for k, v in TOKENS.items()}
DECIMALS = {"ETH": 18, "USDC": 6, "WBTC": 8, "STRK": 18, "EKUBO": 18}
BATCH = 40


def sym(addr):
    return ADDR2SYM.get(addr if isinstance(addr, str) else hex(addr), (addr if isinstance(addr, str) else hex(addr))[:12])


def one(r, i=0):
    if isinstance(r, Exception):
        raise r
    return r[i]


def chunks(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def option_len(amm, lpt, new):
    hi, last = 1, 0
    while hi < 6000:
        r = call(amm, "get_available_options", [lpt, hi])
        if r[1] + r[2] == 0:
            break
        last = hi
        hi *= 2
    if hi >= 6000:
        return last
    lo = last
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        r = call(amm, "get_available_options", [lpt, mid])
        if r[1] + r[2] == 0:
            hi = mid
        else:
            lo = mid
    return lo + 1


def get_options(amm, lpt, n, new):
    opts = []
    for ch in chunks(list(range(n)), BATCH):
        fns = [("get_available_options", [lpt, i]) for i in ch]
        out = call_batch(amm, fns)
        for i, r in zip(ch, out):
            if isinstance(r, Exception):
                raise r
            if r[1] + r[2] == 0:
                continue
            if new:
                opts.append({"side": r[0], "maturity": r[1], "strike": r[2], "sign": r[3],
                             "quote": hex(r[4]), "base": hex(r[5]), "type": r[6]})
            else:
                opts.append({"side": r[0], "maturity": r[1], "strike": r[2],
                             "quote": hex(r[3]), "base": hex(r[4]), "type": r[5]})
        time.sleep(0.15)
    return opts


def get_supplies(amm, lpt, opts, new):
    """For each option entry, get option-token address and totalSupply."""
    fns = []
    for o in opts:
        if new:
            fns.append(("get_option_token_address", [lpt, o["side"], o["maturity"], o["strike"], o["sign"]]))
        else:
            fns.append(("get_option_token_address", [lpt, o["side"], o["maturity"], o["strike"]]))
    addrs = []
    for ch in chunks(fns, BATCH):
        out = call_batch(amm, ch)
        addrs.extend([(r[0] if not isinstance(r, Exception) else None) for r in out])
        time.sleep(0.15)
    # supplies
    sup_fns = []
    for a in addrs:
        if a is None or a == 0:
            sup_fns.append(None)
        else:
            sup_fns.append((hex(a), [("totalSupply", [])]))
    supplies = []
    pend = [(i, a) for i, a in enumerate(addrs) if a]
    for ch in chunks(pend, BATCH):
        reqs = []
        for i, a in ch:
            reqs.append(("starknet_call", [{
                "contract_address": hex(a),
                "entry_point_selector": hex(__import__("sn").sn_keccak("totalSupply")),
                "calldata": [],
            }, "latest"]))
        out = batch(reqs)
        for (i, a), r in zip(ch, out):
            supplies.append((i, None if isinstance(r, Exception) else u256([int(x, 16) for x in r])))
        time.sleep(0.15)
    by_i = dict(supplies)
    return [(hex(a) if a else None, by_i.get(i)) for i, a in enumerate(addrs)]


def terminal_prices(amm, opts, new, quote, base):
    prices = {}
    mats = sorted(set(o["maturity"] for o in opts))
    for m in mats:
        try:
            if new:
                r = call(amm, "get_terminal_price", [quote, base, m])
            else:
                r = call(amm, "get_terminal_price", [19514442401534788, m])
            prices[m] = r[0]
        except Exception as e:
            prices[m] = "ERR:" + str(e)[:120]
    return prices


def payout(opt_type, side, size_float, K_float, T_float):
    """Return payout in the pool's payout currency (base for calls, quote for puts), float."""
    if opt_type == 0:  # CALL
        rel = max(0.0, (T_float - K_float) / T_float) if T_float > 0 else 0.0
        return size_float * (rel if side == 0 else (1.0 - rel))
    else:  # PUT
        return size_float * (max(0.0, K_float - T_float) if side == 0 else min(K_float, T_float))


def main():
    only = None
    if len(sys.argv) > 2 and sys.argv[1] == "--pool":
        only = sys.argv[2]
    out = {"block": block_number(), "prices": {}, "amms": {}}
    try:
        with urllib.request.urlopen("https://coins.llama.fi/prices/current/coingecko:ethereum,coingecko:usd-coin,coingecko:bitcoin,coingecko:starknet", timeout=20) as r:
            out["prices"] = {k: v["price"] for k, v in json.load(r)["coins"].items()}
    except Exception as e:
        out["prices"] = {"ERR": str(e)[:100]}

    for name, amm, new in (("legacy", LEGACY, False), ("new", NEW, True)):
        d = {"pools": {}}
        lps = arr(call(amm, "get_all_lptoken_addresses"))
        d["lptokens"] = [hex(x) for x in lps]
        for lpt in lps:
            key = f"{name}:{hex(lpt)}"
            if only and not (only == f"{name}:{lps.index(lpt)}" or only == key):
                continue
            p = {"lptoken": hex(lpt)}
            pool = call(amm, "get_pool_definition_from_lptoken_address", [lpt])
            p["quote"], p["base"], p["option_type"] = hex(pool[0]), hex(pool[1]), pool[2]
            p["lpool_balance"] = str(u256(call(amm, "get_lpool_balance", [lpt])))
            p["locked_capital"] = str(u256(call(amm, "get_pool_locked_capital", [lpt])))
            p["lp_total_supply"] = str(u256(call(lpt, "totalSupply", [])))
            # exact LP claim (all LP tokens) via the AMM's own view
            try:
                ts = int(p["lp_total_supply"])
                p["lp_claim_total"] = str(u256(call(amm, "get_underlying_for_lptokens", [lpt, ts & (2**128 - 1), ts >> 128])))
            except Exception as e:
                p["lp_claim_total"] = "ERR:" + str(e)[:120]
            n = option_len(amm, lpt, new)
            p["n_options"] = n
            # pool position value views (exact)
            views = [("get_value_of_pool_position", "value_of_pool_position")]
            if new:
                views += [("get_value_of_pool_expired_position", "value_of_pool_expired"),
                          ("get_value_of_pool_non_expired_position", "value_of_pool_non_expired")]
            for fn, key in views:
                try:
                    p[key] = str(call(amm, fn, [lpt])[0])
                except Exception as e:
                    p[key] = "ERR:" + str(e)[:100]
            opts = get_options(amm, lpt, n, new)
            sup = get_supplies(amm, lpt, opts, new)
            prices = terminal_prices(amm, opts, new, p["quote"], p["base"])
            p["terminal_prices_ok"] = sum(1 for v in prices.values() if not isinstance(v, str))
            p["terminal_prices_err"] = {str(m): v for m, v in prices.items() if isinstance(v, str)}
            # aggregate claims in payout currency
            claim_long = 0.0
            claim_short = 0.0
            blocked = {"long": 0.0, "short": 0.0, "maturities": []}
            usym = sym(p["base"] if p["option_type"] == 0 else p["quote"])
            # option-token supplies are always in BASE-token units; WBTC (8 dec) is the only
            # non-18-dec base token in these pools.
            WBTC = "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac"
            scale = 10 ** (8 if int(p["base"], 16) == int(WBTC, 16) else 18)
            div = 2 ** 64 if new else 2 ** 61
            for o, (tok, supply) in zip(opts, sup):
                if not supply:
                    continue
                size = supply / scale  # base-token units
                K = o["strike"] / div
                T = prices.get(o["maturity"])
                if isinstance(T, str):
                    # blocked: record full potential in base/quote units (upper bound)
                    if o["type"] == 0:
                        v = size  # call: max payout = size (base)
                    else:
                        v = size * K  # put: max payout = size*K (quote)
                    blocked["long" if o["side"] == 0 else "short"] += v
                    if o["maturity"] not in blocked["maturities"]:
                        blocked["maturities"].append(o["maturity"])
                    continue
                Tv = T / div
                v = payout(o["type"], o["side"], size, K, Tv)
                if o["side"] == 0:
                    claim_long += v
                else:
                    claim_short += v
            p["underlying_symbol"] = usym
            p["claim_long"] = round(claim_long, 8)
            p["claim_short"] = round(claim_short, 8)
            p["claim_total"] = round(claim_long + claim_short, 8)
            p["blocked"] = {"long": round(blocked["long"], 8), "short": round(blocked["short"], 8),
                            "maturities": blocked["maturities"][:20], "n_blocked_maturities": len(blocked["maturities"])}
            d["pools"][hex(lpt)] = p
            print(f"[{name}] {hex(lpt)[:14]} n={n} long={claim_long:.6f} short={claim_short:.6f} {usym}", file=sys.stderr, flush=True)
        out["amms"][name] = d
    # balances
    out["balances"] = {"legacy": {}, "new": {}, "sister": {}}
    for name, amm in (("legacy", LEGACY), ("new", NEW), ("sister", SISTER)):
        for k, t in TOKENS.items():
            try:
                out["balances"][name][k] = str(u256(call(t, "balanceOf", [amm])))
            except Exception as e:
                out["balances"][name][k] = "ERR:" + str(e)[:80]
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
