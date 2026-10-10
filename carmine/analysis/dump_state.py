#!/usr/bin/env python3
"""Dump live state of Carmine legacy + new AMMs. Read-only.

Outputs JSON to stdout; run with SN_RPC_URL set locally (keyed URL only via env, never in files).
"""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/carmine/analysis")
from sn import call, block_number, u256, arr

LEGACY = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
NEW = "0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9"
GOV = "0x001405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f"
TOKENS = {
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "EKUBO": "0x75afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
}
OPTION_TOKENS = {
    "ETH_USDC_CALL": "0x70cad6be2c3fc48c745e4a4b70ef578d9c79b46ffac4cd93ec7b61f951c7c5c",
    "ETH_USDC_PUT": "0x466e3a6731571cf5d74c5b0d9c508bfb71438de10f9a13269177b01d6f07159",
    "BTC_USDC_CALL": "0x35db72a814c9b30301f646a8fa8c192ff63a0dc82beb390a36e6e9eba55b6db",
    "BTC_USDC_PUT": "0x1bf27366077765c922f342c8de257591d1119ebbcbae7a6c4ff2f50ede4c54c",
    "ETH_STRK_CALL": "0x06df66db6a4b321869b3d1808fc702713b6cbb69541d583d4b38e7b1406c09aa",
    "ETH_STRK_PUT": "0x04dcd9632353ed56e47be78f66a55a04e2c1303ebcb8ec7ea4c53f4fdf3834ec",
    "STRK_USDC_CALL": "0x2b629088a1d30019ef18b893cebab236f84a365402fa0df2f51ec6a01506b1d",
    "STRK_USDC_PUT": "0x6ebf1d8bd43b9b4c5d90fb337c5c0647b406c6c0045da02e6675c43710a326f",
    "EKUBO_USDC_CALL": "0x78a090c99bfc993fe8bbd19487351e501dbe7b50ab695966605e0839b34182a",
    "EKUBO_USDC_PUT": "0xe12a16c964dc68850c1f6cbea9062c36bed7676265eec7f563c728c53e536f",
}


def bal(token, addr):
    try:
        r = call(token, "balanceOf", [addr])
        return u256(r)
    except Exception as e:
        return f"ERR: {e}"


def main():
    out = {"block": block_number()}
    blk = hex(out["block"])

    out["legacy"] = {}
    out["new"] = {}

    # legacy reads
    for fn, key in [("getImplementationHash", "impl_hash"), ("getAdmin", "admin"),
                    ("get_trading_halt", "halt"), ("get_max_option_size_percent_of_voladjspd", "max_opt_pct")]:
        try:
            out["legacy"][key] = hex(call(LEGACY, fn, block=blk)[0])
        except Exception as e:
            out["legacy"][key] = f"ERR: {e}"
    try:
        r = call(LEGACY, "get_all_lptoken_addresses", block=blk)
        out["legacy"]["lptokens"] = [hex(x) for x in arr(r)]
    except Exception as e:
        out["legacy"]["lptokens"] = f"ERR: {e}"
    try:
        idx = []
        i = 0
        while i < 30:
            a = call(LEGACY, "get_available_lptoken_addresses", [i], block=blk)[0]
            if a == 0:
                break
            idx.append(hex(a))
            i += 1
        out["legacy"]["lptokens_indexed"] = idx
    except Exception as e:
        out["legacy"]["lptokens_indexed"] = f"ERR: {e}"

    # legacy balances
    out["legacy"]["balances"] = {k: bal(v, LEGACY) for k, v in TOKENS.items()}

    # new reads
    for fn, key in [("owner", "owner"), ("get_trading_halt", "halt"),
                    ("get_fees_percentage", "fees_pct"),
                    ("get_max_option_size_percent_of_voladjspd", "max_opt_pct")]:
        try:
            out["new"][key] = hex(call(NEW, fn, block=blk)[0])
        except Exception as e:
            out["new"][key] = f"ERR: {e}"
    try:
        r = call(NEW, "get_all_lptoken_addresses", block=blk)
        out["new"]["lptokens"] = [hex(x) for x in arr(r)]
    except Exception as e:
        out["new"]["lptokens"] = f"ERR: {e}"
    for tok in ["ETH", "USDC", "WBTC", "STRK", "EKUBO"]:
        try:
            out["new"][f"max_lpool_balance_{tok}"] = u256(call(NEW, "get_max_lpool_balance", [TOKENS[tok]], block=blk))
        except Exception as e:
            out["new"][f"max_lpool_balance_{tok}"] = f"ERR: {e}"

    out["new"]["balances"] = {k: bal(v, NEW) for k, v in TOKENS.items()}
    out["gov_balances"] = {k: bal(v, GOV) for k, v in TOKENS.items()}
    out["option_token_balances"] = {k: {t: bal(v, t) for t in ["ETH", "USDC"]} for k, v in OPTION_TOKENS.items()}

    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
