#!/usr/bin/env python3
"""
C2-50 Vesu V1.1 — live state fetch (read-only).

Reads at a pinned block:
  - class hashes of all Vesu V1 contracts
  - owner/pending_owner/singleton_v1/upgrade_name on the V1.1 singleton
  - extension whitelist entries
  - pool_id -> extension for the documented V1 pools
  - ERC20 balances of the singleton, deprecated singleton, extensions, utilities
  - USD prices via DefiLlama

Writes JSON to analysis/live_state.json (no secrets).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vesu_rpc import (  # noqa: E402
    call_view, erc20_balance, erc20_decimals, get_block_number, get_class_hash_at,
    price_usd, to_int, u256_from_felts, rpc,
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live_state.json")
_ciout = os.environ.get("CI_OUT")
if _ciout:
    os.makedirs(_ciout, exist_ok=True)
    OUT = os.path.join(os.path.abspath(_ciout), "live_state.json")

# ---------------------------------------------------------------------------
# registry (Starknet mainnet)
# ---------------------------------------------------------------------------
V11_SINGLETON = "0x000d8d6dfec4d33bfb6895de9f3852143a17c6f92fd2a21da3d6924d34870160"  # current V1 singleton ("V1.1")
V10_SINGLETON = "0x2545b2e5d519fc230e9cd781046d3a64e092114f07e44771e0d719d148725ef"  # deprecated V1 (pre-migration)
EXT_PO_CURRENT = "0x4e06e04b8d624d039aa1c3ca8e0aa9e21dc1ccba1d88d0d650837159e0ee054"
EXT_DEP = "0x2334189e831d804d4a11d3f71d4a982ec82614ac12ed2e9ca2f8da4e6374fa"
EXT_DEP_PO = "0x7cf3881eb4a58e76b41a792fa151510e7057037d80eda334682bd3e73389ec0"
EXT_DEP_CL = "0x4e09a4fa7ab1a6b08693f5d89ab0b9db2de00a9b7d1c8f8ad286a665effd446"

UTILS = {
    "legacy_multiply": "0x219ce882a208653c3f96eac91b96616c94772600a35431b5b6a4e485c1dd0b2",
    "legacy_liquidate": "0x06f77dd7b8a4e34ef712505735f7259fe900b1ed2e2b673cd380c57da3d27dd8",
    "legacy_rebalance": "0x7967c37a99caa107eef98af43ae51c0624135557949c1214af3770aef651e12",
    "legacy_distributor": "0x0387f3eb1d98632fbe3440a9f1385aec9d87b6172491d3dd81f1c35a7c61048f",
    "current_multiply": "0x3630f1f8e5b8f5c4c4ae9b6620f8a570ae55cddebc0276c37550e7c118edf67",
    "current_liquidate": "0x58c80ed9801b32b441566d320ae236c73257981800dcda63c9f02dd154c3f39",
}

V2 = {
    "pool_factory": "0x3760f903a37948f97302736f89ce30290e45f441559325026842b7a6fb388c0",
    "oracle": "0xfe4bfb1b353ba51eb34dff963017f94af5a5cf8bdf3dfc191c504657f3c05",
    "migrate": "0x02c4399cfb357f836303d16e8173e4de71b4ba78d97121211357a6d73b9f9213",
    "prime_pool": "0x451fe483d5921a2919ddd81d0de6696669bccdacd859f72a4fba7656b97c3b5",
}

ASSETS = {
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "wBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "wstETH": "0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b",
    "wstETH_legacy": "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "xSTRK": "0x028d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a",
    "sSTRK": "0x0356f304b154d29d2a8fe22f1cb9107a9b564a733cf6b4cc47fd121ac1af90c9",
    "rUSDC": "0x02019e47a0bc54ea6b4853c6123ffc8158ea3ae2af4166928b0de6e89f06de6c",
    "EKUBO": "0x075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
    "DOG": "0x040e81cfeb176bfdbc5047bbc55eb471cfab20a6b221f38d8fda134e1bfffca4",
}

POOLS_DEC = {
    "Genesis": 2198503327643286920898110335698706244522220458610657370981979460625005526824,
    "Re7_USDC": 3592370751539490711610556844458488648008775713878064059760995781404350938653,
    "Re7_xSTRK": 2345856225134458665876812536882617294246962319062565703131100435311373119841,
    "Re7_rUSDC": 1749206066145585665304376624725901901307432885480056836110792804696449290137,
    "Re7_Starknet_Ecosystem": 3163948199181372152800322058764275087686391083665033264234338943786798617741,
    "Re7_wstETH": 2535243615249328221060622268479728814680175138265908305094759253778126318519,
    "Braavos_Vault": 1921054942193708428619433636456748851087331856691656881799540576257302014718,
    "Alterscope_CASH": 3496574735728882918499284446337009546448797063742922299223215375275805529443,
    "Alterscope_Cornerstone": 1159811069645890520539813878756846008647087829665407214583864910459307655916,
    "Alterscope_wstETH": 2612229586214495842527551768232431476062656055007024497123940017576986139174,
    "CarmineDAO_Runes": 2681185522664180117929158590481443496806090795357786716961716864181408932939,
}

VIEW_TARGETS = {
    "V1.1_singleton": V11_SINGLETON,
    "V1.0_deprecated_singleton": V10_SINGLETON,
    "extension_PO_current": EXT_PO_CURRENT,
    "extension_deprecated": EXT_DEP,
    "extension_deprecated_PO": EXT_DEP_PO,
    "extension_deprecated_CL": EXT_DEP_CL,
    **{f"util_{k}": v for k, v in UTILS.items()},
    **{f"v2_{k}": v for k, v in V2.items()},
}


def main():
    block = get_block_number()
    print(f"[state] pinned block: {block}")
    out = {"block": block, "timestamp_fetch": None, "classes": {}, "singleton_v11": {}, "pools": {},
           "balances": {}, "prices": {}, "decimals": {}}

    # 1. class hashes at pinned block
    for name, addr in VIEW_TARGETS.items():
        ch = get_class_hash_at(addr, block=block)
        out["classes"][name] = {"address": addr, "class_hash": ch if isinstance(ch, str) else None,
                                "error": None if isinstance(ch, str) else ch}

    # 2. singleton V1.1 admin state
    for fn in ("owner", "pending_owner", "singleton_v1", "upgrade_name"):
        res = call_view(V11_SINGLETON, fn, [], block=block)
        out["singleton_v11"][fn] = res

    # 2b. same for deprecated singleton (V1.0) + current extension owner state
    out["singleton_v10"] = {}
    for fn in ("owner", "pending_owner", "singleton_v1", "upgrade_name"):
        res = call_view(V10_SINGLETON, fn, [], block=block)
        out["singleton_v10"][fn] = res

    # 3. whitelist state on V1.1 singleton
    out["whitelist"] = {}
    for name, addr in [("ext_PO_current", EXT_PO_CURRENT), ("ext_deprecated", EXT_DEP),
                       ("ext_dep_PO", EXT_DEP_PO), ("ext_dep_CL", EXT_DEP_CL)]:
        res = call_view(V11_SINGLETON, "whitelisted_extension", [addr], block=block)
        out["whitelist"][name] = res

    # 4. pools -> extension on V1.1 singleton
    for name, dec in POOLS_DEC.items():
        pid = hex(dec)
        res = call_view(V11_SINGLETON, "extension", [pid], block=block)
        ext = None
        if isinstance(res, list) and res:
            ext = hex(to_int(res[0]))
        out["pools"][name] = {"pool_id_dec": str(dec), "pool_id_hex": pid, "extension": ext,
                              "raw": res}
    # same on deprecated singleton (for reference)
    out["pools_v10"] = {}
    for name, dec in POOLS_DEC.items():
        res = call_view(V10_SINGLETON, "extension", [hex(dec)], block=block)
        ext = None
        if isinstance(res, list) and res:
            ext = hex(to_int(res[0]))
        out["pools_v10"][name] = {"extension": ext, "raw": res}

    # 5. token decimals
    for name, addr in ASSETS.items():
        out["decimals"][name] = erc20_decimals(addr, block=block)

    # 6. balances
    holders = {"V1.1_singleton": V11_SINGLETON, "V1.0_singleton": V10_SINGLETON,
               "ext_PO_current": EXT_PO_CURRENT, "ext_deprecated": EXT_DEP,
               "ext_dep_PO": EXT_DEP_PO, "ext_dep_CL": EXT_DEP_CL,
               **UTILS, **V2}
    for hname, haddr in holders.items():
        out["balances"][hname] = {}
        for aname, aaddr in ASSETS.items():
            bal = erc20_balance(aaddr, haddr, block=block)
            if bal:
                out["balances"][hname][aname] = str(bal)

    # 7. USD prices from DefiLlama
    ids = [f"starknet:{a}" for a in ASSETS.values()]
    out["prices"] = price_usd(ids)

    with open(OUT, "w") as f:
        json.dump(out, f, indent=2)
    print(f"[state] wrote {OUT}")

    # quick summary
    print("\n== balances of V1.1 singleton (raw) ==")
    for aname, bal in out["balances"]["V1.1_singleton"].items():
        print(f"  {aname}: {bal}")
    print("\n== owner state ==")
    print("  V1.1 owner raw:", out["singleton_v11"]["owner"])
    print("  V1.1 singleton_v1 raw:", out["singleton_v11"]["singleton_v1"])
    print("  whitelist PO current:", out["whitelist"]["ext_PO_current"])
    for pname, p in out["pools"].items():
        print(f"  pool {pname}: ext={p['extension']}")


if __name__ == "__main__":
    main()
