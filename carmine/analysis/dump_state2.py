#!/usr/bin/env python3
"""Dump full pool state of both Carmine AMMs (read-only)."""
import json, sys, time
sys.path.insert(0, "/home/heisenberg/CA/carmine/analysis")
from sn import call, block_number, u256, arr

LEGACY = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
NEW = "0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9"
TOKENS = {
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "EKUBO": "0x75afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
}
ADDR2NAME = {v: k for k, v in TOKENS.items()}


def safe(fn, *a, **kw):
    try:
        return fn(*a, **kw)
    except Exception as e:
        return f"ERR: {str(e)[:200]}"


def bal(token, addr):
    r = safe(call, token, "balanceOf", [addr])
    if isinstance(r, str):
        return r
    return str(u256(r))


def hexs(v):
    return hex(v) if isinstance(v, int) else v


def main():
    out = {"block": block_number()}
    out["legacy"] = {"pools": {}, "views": {}}
    out["new"] = {"pools": {}, "views": {}}

    # ---------- legacy ----------
    L = out["legacy"]
    for fn, key in [("getImplementationHash", "impl_hash"), ("getAdmin", "admin"),
                    ("get_trading_halt", "halt"), ("get_max_option_size_percent_of_voladjspd", "max_opt_pct")]:
        r = safe(call, LEGACY, fn)
        L["views"][key] = hexs(r[0]) if not isinstance(r, str) else r
    r = safe(call, LEGACY, "get_all_lptoken_addresses")
    lpts = arr(r) if not isinstance(r, str) else []
    L["views"]["lptokens"] = [hexs(x) for x in lpts]
    for lpt in lpts:
        lp = hexs(lpt)
        d = {}
        r = safe(call, LEGACY, "get_pool_definition_from_lptoken_address", [lpt])
        if not isinstance(r, str):
            # Pool struct: quote, base, option_type
            d["quote"] = hexs(r[0]); d["base"] = hexs(r[1]); d["option_type"] = r[2]
            d["underlying"] = hexs(safe(call, LEGACY, "get_underlying_token_address", [lpt])[0]) if not isinstance(safe(call, LEGACY, "get_underlying_token_address", [lpt]), str) else None
        d["lpool_balance"] = safe(lambda: str(u256(call(LEGACY, "get_lpool_balance", [lpt]))))
        d["locked_capital"] = safe(lambda: str(u256(call(LEGACY, "get_pool_locked_capital", [lpt]))))
        d["unlocked"] = safe(lambda: str(u256(call(LEGACY, "get_unlocked_capital", [lpt]))))
        d["adj_speed"] = safe(lambda: str(call(LEGACY, "get_pool_volatility_adjustment_speed", [lpt])[0]))
        r = safe(call, LEGACY, "get_available_options", [lpt, 0])
        opts = []
        i = 0
        while i < 40:
            r = safe(call, LEGACY, "get_available_options", [lpt, i])
            if isinstance(r, str):
                opts.append(r); break
            # Option struct: option_side, maturity, strike, quote, base, type
            if r[1] + r[2] == 0:
                break
            o = {"idx": i, "side": r[0], "maturity": r[1], "strike": hexs(r[2]),
                 "quote": hexs(r[3]), "base": hexs(r[4]), "type": r[5]}
            # pool positions both sides
            o["pos_long"] = safe(lambda oo=o: str(call(LEGACY, "get_option_position", [lpt, 0, oo["maturity"], int(oo["strike"], 16)])[0]))
            o["pos_short"] = safe(lambda oo=o: str(call(LEGACY, "get_option_position", [lpt, 1, oo["maturity"], int(oo["strike"], 16)])[0]))
            o["vol"] = safe(lambda oo=o: str(call(LEGACY, "get_pool_volatility_separate", [lpt, oo["maturity"], int(oo["strike"], 16)])[0]))
            o["opt_token_long"] = safe(lambda oo=o: hexs(call(LEGACY, "get_option_token_address", [lpt, 0, oo["maturity"], int(oo["strike"], 16)])[0]))
            o["opt_token_short"] = safe(lambda oo=o: hexs(call(LEGACY, "get_option_token_address", [lpt, 1, oo["maturity"], int(oo["strike"], 16)])[0]))
            opts.append(o)
            i += 1
        d["options"] = opts
        L["pools"][lp] = d

    # ---------- new ----------
    N = out["new"]
    for fn, key in [("owner", "owner"), ("get_trading_halt", "halt"), ("get_fees_percentage", "fees_pct"),
                    ("get_max_option_size_percent_of_voladjspd", "max_opt_pct")]:
        r = safe(call, NEW, fn)
        N["views"][key] = hexs(r[0]) if not isinstance(r, str) else r
    r = safe(call, NEW, "get_all_lptoken_addresses")
    lpts = arr(r) if not isinstance(r, str) else []
    N["views"]["lptokens"] = [hexs(x) for x in lpts]
    for lpt in lpts:
        lp = hexs(lpt)
        d = {}
        r = safe(call, NEW, "get_pool_definition_from_lptoken_address", [lpt])
        if not isinstance(r, str):
            d["quote"] = hexs(r[0]); d["base"] = hexs(r[1]); d["option_type"] = r[2]
        d["lpool_balance"] = safe(lambda: str(u256(call(NEW, "get_lpool_balance", [lpt]))))
        d["locked_capital"] = safe(lambda: str(u256(call(NEW, "get_pool_locked_capital", [lpt]))))
        d["unlocked"] = safe(lambda: str(u256(call(NEW, "get_unlocked_capital", [lpt]))))
        d["adj_speed"] = safe(lambda: str(call(NEW, "get_pool_volatility_adjustment_speed", [lpt])[0]))
        d["lp_total_supply"] = safe(lambda: str(u256(call(lpt, "totalSupply", []))))
        r = safe(call, NEW, "get_available_options", [lpt, 0])
        opts = []
        i = 0
        while i < 60:
            r = safe(call, NEW, "get_available_options", [lpt, i])
            if isinstance(r, str):
                opts.append(r); break
            if r[1] + r[2] == 0:
                break
            o = {"idx": i, "side": r[0], "maturity": r[1], "strike": hexs(r[2]),
                 "quote": hexs(r[3]), "base": hexs(r[4]), "type": r[5]}
            o["pos_long"] = safe(lambda oo=o: str(call(NEW, "get_option_position", [lpt, 0, oo["maturity"], int(oo["strike"], 16)])[0]))
            o["pos_short"] = safe(lambda oo=o: str(call(NEW, "get_option_position", [lpt, 1, oo["maturity"], int(oo["strike"], 16)])[0]))
            o["vol"] = safe(lambda oo=o: str(call(NEW, "get_option_volatility", [lpt, oo["maturity"], int(oo["strike"], 16)])[0]))
            opts.append(o)
            i += 1
        d["options"] = opts
        N["pools"][lp] = d

    out["balances"] = {
        "legacy": {k: bal(v, LEGACY) for k, v in TOKENS.items()},
        "new": {k: bal(v, NEW) for k, v in TOKENS.items()},
    }
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
