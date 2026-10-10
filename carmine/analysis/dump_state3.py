#!/usr/bin/env python3
"""Fast batched dump of Carmine legacy + new AMM pool state (read-only)."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/carmine/analysis")
from sn import call_batch, call, block_number, u256, arr

LEGACY = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
NEW = "0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9"


def sc(*a, **kw):
    try:
        return call(*a, **kw)
    except Exception as e:
        return "ERR: " + str(e)[:160]


def one(v, idx=0):
    if isinstance(v, str):
        return v
    return v[idx]


def get_options(amm, lpt, new=False, max_opts=80):
    idxs = list(range(max_opts))
    fns = [("get_available_options", [lpt, i]) for i in idxs]
    out = call_batch(amm, fns)
    opts = []
    for i, r in enumerate(out):
        if isinstance(r, Exception):
            opts.append({"idx": i, "err": str(r)[:100]})
            break
        if new:
            if r[1] + r[2] == 0:
                break
            opts.append({"idx": i, "side": r[0], "maturity": r[1], "strike": r[2], "strike_sign": r[3],
                         "quote": hex(r[4]), "base": hex(r[5]), "type": r[6]})
        else:
            if r[1] + r[2] == 0:
                break
            opts.append({"idx": i, "side": r[0], "maturity": r[1], "strike": r[2],
                         "quote": hex(r[3]), "base": hex(r[4]), "type": r[5]})
    fns = []
    for o in opts:
        if "err" in o:
            continue
        st = [o["strike"], o["strike_sign"]] if new else [o["strike"]]
        for side in (0, 1):
            fns.append(("get_option_position", [lpt, side, o["maturity"]] + st))
        if new:
            fns.append(("get_option_volatility", [lpt, o["maturity"]] + st))
            fns.append(("get_option_token_address", [lpt, o["side"], o["maturity"]] + st))
        else:
            fns.append(("get_pool_volatility_separate", [lpt, o["maturity"]] + st))
            fns.append(("get_option_token_address", [lpt, o["side"], o["maturity"]] + st))
    out = call_batch(amm, fns)
    k = 0
    for o in opts:
        if "err" in o:
            continue
        o["pos_long"] = one(out[k]); k += 1
        o["pos_short"] = one(out[k]); k += 1
        o["vol"] = one(out[k]); k += 1
        o["tok"] = one(out[k]) if not isinstance(one(out[k]), str) else one(out[k])
        if not isinstance(o["tok"], str):
            o["tok"] = hex(o["tok"])
        k += 1
    return opts


def main():
    out = {"block": block_number(), "legacy": {}, "new": {}}
    for name, amm in (("legacy", LEGACY), ("new", NEW)):
        d = out[name]
        lpts = arr(sc(amm, "get_all_lptoken_addresses"))
        d["lptokens"] = [hex(x) for x in lpts]
        d["pools"] = {}
        for lpt in lpts:
            p = {}
            r = sc(amm, "get_pool_definition_from_lptoken_address", [lpt])
            if not isinstance(r, str):
                p["quote"] = hex(r[0]); p["base"] = hex(r[1]); p["option_type"] = r[2]
            for fn, key, conv in [("get_lpool_balance", "lpool_balance", "u256"),
                                  ("get_pool_locked_capital", "locked_capital", "u256"),
                                  ("get_unlocked_capital", "unlocked", "u256"),
                                  ("get_pool_volatility_adjustment_speed", "adj_speed", "f"),
                                  ("totalSupply", "lp_total_supply", "u256")]:
                tgt = lpt if fn == "totalSupply" else amm
                r = sc(tgt, fn, [lpt] if fn != "totalSupply" else [])
                p[key] = str(u256(r)) if conv == "u256" and not isinstance(r, str) else one(r)
            p["options"] = get_options(amm, lpt, new=(name == "new"))
            d["pools"][hex(lpt)] = p
            print(f"[{name}] {hex(lpt)} done: {len(p['options'])} options", file=sys.stderr)
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
