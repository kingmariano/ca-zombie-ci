#!/usr/bin/env python3
"""Static live-state reads per chain: config, roles, balances, proxy internals.

Read-only. Writes raw/static_<chain>.json
"""
import json
import os
import sys

from rpc import Rpc

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")

CHAINS = {
    "base": dict(
        rpc="https://base-rpc.publicnode.com",
        diamond="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43",
        mas=["0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86"],
        collateral="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", dec=6,
        extra_tokens={"INTX": "0x7d27187eb33a7b1d99258ff222633670f84fa342"}),
    "arb": dict(
        rpc="https://arb1.arbitrum.io/rpc",
        diamond="0x8F06459f184553e5d04F07F868720BDaCAB39395",
        mas=["0x141269E29a770644C34e05B127AB621511f20109"],
        collateral="0xaf88d065e77c8cC2239327C5EDb3A432268e5831", dec=6,
        extra_tokens={}),
    "mantle": dict(
        rpc="https://rpc.mantle.xyz",
        diamond="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5",
        mas=["0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456"],
        collateral="0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34", dec=18,
        extra_tokens={}),
    "blast": dict(
        rpc="https://blast-rpc.publicnode.com",
        diamond="0x3d17f073cCb9c3764F105550B0BCF9550477D266",
        mas=["0x083267D20Dbe6C2b0A83Bd0E601dC2299eD99015",
             "0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e"],
        collateral="0x4300000000000000000000000000000000000003", dec=18,
        extra_tokens={}),
}

ROLE_NAMES = [
    "DEFAULT_ADMIN_ROLE", "ADMIN_ROLE", "CONTROLLER_ROLE", "PAUSER_ROLE",
    "UNPAUSER_ROLE", "SETTER_ROLE", "MUON_SETTER_ROLE", "SUSPENDED_ROLE",
    "LIQUIDATOR_ROLE", "EMERGENCY_ROLE", "MASTER_ROLE", "VIEW_ROLE",
    "WITHDRAWER_ROLE", "OWNER_ROLE", "OPERATOR_ROLE",
]

CANDIDATE_ADMINS = [
    "0x9BC9CA7e6A8F013f40617c4585508A988DB7C1c7",
    "0x319F10D14B5B7195a1693f4f5C015370C4324Fa6",
    "0x67736569B61BdB7F1A756EF069aB5B9590668E4c",
]

# EIP-1967 slots
SLOT_IMPL = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
SLOT_ADMIN = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103

DIAMOND_VIEWS = [
    "getCollateral", "pauseState", "pauseState_9", "liquidationTimeout", "liquidatorShare",
    "getMuonConfig", "getMuonIds", "getFeeCollector", "getBalanceLimitPerUser",
    "pendingQuotesValidLength", "coolDownsOfMA", "isCrossPartyBModeActivated",
    "isLegacyDeallocateDeprecated", "owner", "pendingOwner", "forceCloseGapRatio",
    "withdrawCooldownPeriod", "getLiquidatorFee",
]


def addr_from_storage(word):
    if not word or word == "0x" + "0" * 64:
        return None
    return "0x" + word[-40:]


def one(v):
    if isinstance(v, (tuple, list)) and len(v) == 1:
        return v[0]
    return v


def run(chain):
    cfg = CHAINS[chain]
    r = Rpc(cfg["rpc"])
    block = r.block_number()
    bh = hex(block)
    out = {"chain": chain, "block": block, "diamond": cfg["diamond"]}
    print(f"[{chain}] block {block}")

    calls = [(name, [], cfg["diamond"]) for name in DIAMOND_VIEWS]
    res = r.batch_call(calls, bh)
    diamond_views = {}
    for (name, _, _), val in zip(calls, res):
        diamond_views[name] = one(val)
        print(f"  diamond.{name} = {val}")
    out["diamond_views"] = diamond_views

    # roles
    role_hashes = {}
    calls = [("getRoleHash", [name], cfg["diamond"]) for name in ROLE_NAMES]
    res = r.batch_call(calls, bh)
    for name, val in zip(ROLE_NAMES, res):
        val = one(val)
        if val:
            role_hashes[name] = "0x" + val.hex() if isinstance(val, bytes) else str(val)
    out["role_hashes"] = role_hashes

    calls = []
    labels = []
    for name, rh in role_hashes.items():
        for cand in CANDIDATE_ADMINS:
            calls.append(("hasRole", [cand, bytes.fromhex(rh[2:])], cfg["diamond"]))
            labels.append((name, cand))
    res = r.batch_call(calls, bh)
    out["candidate_roles"] = {}
    for (name, cand), val in zip(labels, res):
        if one(val):
            out["candidate_roles"].setdefault(cand, []).append(name)
            print(f"  ROLE {name} -> {cand}")

    # balances
    bal = {}
    coll = diamond_views.get("getCollateral") or cfg["collateral"]
    calls = [("balanceOf", [cfg["diamond"]], coll if isinstance(coll, str) else coll[0])]
    res = r.batch_call(calls, bh)
    bal["diamond_collateral"] = one(res[0])
    bal["diamond_native"] = r.get_balance(cfg["diamond"], bh)
    out["balances"] = bal
    print(f"  diamond collateral raw = {bal['diamond_collateral']}, native = {bal['diamond_native']}")

    # MultiAccounts
    out["multiaccounts"] = {}
    for ma in cfg["mas"]:
        info = {}
        res = r.batch_call([("paused", [], ma), ("deusV3Address", [], ma)], bh)
        info["paused"] = one(res[0])
        info["deusV3Address"] = one(res[1])
        impl = addr_from_storage(r.get_storage_at(ma, SLOT_IMPL, bh))
        admin = addr_from_storage(r.get_storage_at(ma, SLOT_ADMIN, bh))
        info["eip1967_impl"] = impl
        info["eip1967_admin"] = admin
        try:
            res = r.batch_call([("implementation", [], ma), ("admin", [], ma), ("owner", [], ma)], bh)
            info["implementation_fn"] = one(res[0])
            info["admin_fn"] = one(res[1])
            info["owner_fn"] = one(res[2])
        except Exception as e:
            info["fn_error"] = str(e)
        res = r.batch_call([("balanceOf", [ma], coll if isinstance(coll, str) else coll[0])], bh)
        info["collateral_balance"] = one(res[0])
        info["native_balance"] = r.get_balance(ma, bh)
        info["code_size"] = len(r.get_code(ma, bh) or "0x") // 2
        out["multiaccounts"][ma] = info
        print(f"  MA {ma}: paused={info['paused']} impl={impl} admin={admin} coll={info['collateral_balance']}")

    # collateral token info
    tok = {}
    res = r.batch_call([("name", [], cfg["collateral"]), ("symbol", [], cfg["collateral"]),
                        ("decimals", [], cfg["collateral"]), ("totalSupply", [], cfg["collateral"])], bh)
    tok["name"], tok["symbol"], tok["decimals"], tok["totalSupply"] = [one(x) for x in res]
    out["collateral_token"] = tok
    # extra tokens balances for diamond/MAs
    out["extra_token_balances"] = {}
    for tname, taddr in cfg.get("extra_tokens", {}).items():
        addrs = [cfg["diamond"]] + cfg["mas"]
        calls = [("balanceOf", [a], taddr) for a in addrs]
        res = r.batch_call(calls, bh)
        out["extra_token_balances"][tname] = {a: one(x) for a, x in zip(addrs, res)}

    with open(os.path.join(RAW, f"static_{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{chain}] static written")


if __name__ == "__main__":
    for c in sys.argv[1:] or CHAINS:
        run(c)
