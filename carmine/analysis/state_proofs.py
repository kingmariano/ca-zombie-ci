#!/usr/bin/env python3
"""Live-state proofs for Carmine (C2-47): key read-only citations with block numbers.

Writes JSON to stdout. Keyless public RPC (SN_RPC_URL override; never store keys).
"""
import json, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sn import call, call_batch, block_number, class_hash_at, u256, arr

LEGACY = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
NEW = "0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9"
SISTER = "0x1007d87af0a2b9b6199f5f09ab9c230f415470eeceb5a8b01590c51229da562"
GOV = "0x001405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f"
TOKENS = {
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "EKUBO": "0x75afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
}


def sc(*a, **kw):
    try:
        return call(*a, **kw)
    except Exception as e:
        return "ERR:" + str(e)[:160]


def one(v, i=0):
    return v if isinstance(v, str) else v[i]


def main():
    out = {"block": block_number(), "legacy": {}, "new": {}, "sister": {}, "governance": {}}
    L, N, S, G = out["legacy"], out["new"], out["sister"], out["governance"]

    L["address"] = LEGACY
    N["address"] = NEW
    S["address"] = SISTER
    L["class_hash_at"] = class_hash_at(LEGACY)
    N["class_hash_at"] = class_hash_at(NEW)
    S["class_hash_at"] = class_hash_at(SISTER)
    L["implementation_hash"] = one(sc(LEGACY, "getImplementationHash"))
    L["admin"] = one(sc(LEGACY, "getAdmin"))
    N["owner"] = one(sc(NEW, "owner"))
    G["get_amm_address"] = one(sc(GOV, "get_amm_address"))
    L["trading_halt"] = one(sc(LEGACY, "get_trading_halt"))
    N["trading_halt"] = one(sc(NEW, "get_trading_halt"))
    L["max_option_size_pct_of_voladjspd"] = one(sc(LEGACY, "get_max_option_size_percent_of_voladjspd"))
    N["max_option_size_pct_of_voladjspd"] = one(sc(NEW, "get_max_option_size_percent_of_voladjspd"))
    N["fees_percentage"] = one(sc(NEW, "get_fees_percentage"))

    # balances
    for name, addr in (("legacy", LEGACY), ("new", NEW), ("sister", SISTER)):
        d = out[name]
        d["balances"] = {}
        for k, t in TOKENS.items():
            r = sc(t, "balanceOf", [addr])
            d["balances"][k] = "ERR" if isinstance(r, str) else str(u256(r))

    # pools + zero non-expired options + lp claims + locked capital
    for name, amm in (("legacy", LEGACY), ("new", NEW)):
        d = out[name]
        lps = arr(sc(amm, "get_all_lptoken_addresses"))
        d["n_pools"] = len(lps)
        d["pools"] = {}
        for lpt in lps:
            p = {}
            pool = sc(amm, "get_pool_definition_from_lptoken_address", [lpt])
            if not isinstance(pool, str):
                p["quote"] = hex(pool[0]); p["base"] = hex(pool[1]); p["option_type"] = pool[2]
            p["lpool_balance"] = one(sc(amm, "get_lpool_balance", [lpt]))
            p["locked_capital"] = one(sc(amm, "get_pool_locked_capital", [lpt]))
            p["unlocked_capital"] = one(sc(amm, "get_unlocked_capital", [lpt]))
            p["lp_total_supply"] = one(sc(lpt, "totalSupply", []))
            ne = sc(amm, "get_all_non_expired_options_with_premia", [lpt])
            p["non_expired_options"] = one(ne) if not isinstance(ne, str) else ne
            d["pools"][hex(lpt)] = p
    # permissionless probes on new AMM (caller=0)
    probes = {}
    for fn, args in [("set_pragma_required_checkpoints", []),
                     ("set_pragma_checkpoint", [19514442401534788]),
                     ("upgrade", [0x7fb1aa680d9c02e1017d5ed048612630c30d11991d43b3e4e7a22531621cd5c]),
                     ("set_trading_halt", [1]),
                     ("add_option_both_sides", [2000000000, 1000 * 2**64, 0, TOKENS["USDC"], TOKENS["ETH"], 0,
                                                0x70cad6be2c3fc48c745e4a4b70ef578d9c79b46ffac4cd93ec7b61f951c7c5c,
                                                0x7850516e7685381f0bac0ce9be6481e64b4415375fe2b819a2144cc556d8778,
                                                0x1, 100 * 2**64, 0])]:
        try:
            r = call(NEW, fn, args)
            probes[fn] = {"result": "EXECUTED_NO_REVERT", "ret": [hex(x) for x in r[:3]]}
        except Exception as e:
            probes[fn] = {"result": "revert", "msg": str(e)[:220]}
    out["new"]["permissionless_probes_caller_zero"] = probes
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
