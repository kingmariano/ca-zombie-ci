#!/usr/bin/env python3
"""Stage 1 probe: Nest protocol on HyperEVM at one explicit block.
- all 72 pool addresses (69 V3 + 3 V2) from API snapshot
- on-chain poolToGauge + FeesVaultFactory.getVaultForPool per pool
- gauge implementation + sample gauge selectors
- core NEST balance holders, veNEST stats
- Algebra community vault / factory token balances
Read-only.
"""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

VOTER = "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901"
FVF = "0x705C76e29977Ed52cd93d390A7BBcC61189724C0"
VEFACT = "0x15eb3987A7edC464e5A4d3bC3A9b8E84b8ceE2C7"
V3FACT = "0x09D1A533032319557196F87dFf831FF46204c49d"
GAUGE_IMPL_PROBE = "0x9f8d07dd76182c80570e47bae1d462d77319ee90"  # sample V3 gauge
NEST = "0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035"
VENEST = "0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074"
MINTER = "0x574f6865140e6929bDed24596D78a8D9c07E356d"
VENEST_IMPL = "0xf70526a0089fdc334814c3498ca1ba30c25aba91"
ADDR_6652 = "0x6652173b0cb3d96d8f0198bc49670440dec69e79"
ALG_VAULT = "0x15E408A37cE4D13218202C0054B0f485E38F5768"
ALG_FACTORY = "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3"
TOP_TOKENS = {
    "WHYPE": "0x5555555555555555555555555555555555555555",
    "USDC": "0xb88339CB7199b77E23DB6E890353E22632Ba630f",
    "USDT0": "0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb",
    "UBTC": "0x9FDBdA0A5e284c32744D2f17Ee5c74B284993463",
    "UETH": "0xBe6727B535545C67d5cAa73dEa54865B92CF7907",
    "KHYPE": "0xfD739d4e423301CE9385c1fb8850539D657C296D",
    "NEST": NEST,
}


def pad(addr):
    return addr.lower().replace("0x", "").rjust(64, "0")


def main():
    pools = json.load(open("/home/heisenberg/CA/hyperevm-residuals/analysis/nest_pools_api.json"))
    bn = block_number()
    B = hex(bn)
    print("block:", bn, "pools:", len(pools))

    out = {"block": bn, "pools": {}}

    calls, meta = [], []
    # per pool: code, poolToGauge, getVaultForPool
    for p in pools:
        a = p["id"]
        calls.append(("eth_getCode", [a, B])); meta.append(("code", a, None))
        calls.append(("eth_call", [{"to": VOTER, "data": "0xaa3f22b8" + pad(a)}, B])); meta.append(("poolToGauge_voter", a, None))
        calls.append(("eth_call", [{"to": FVF, "data": "0x7570e389" + pad(a)}, B])); meta.append(("getVaultForPool", a, None))
    # factories / core getters
    extra = [
        (FVF, "feesVaultImplementation()", "0xd5343e86"),
        (VEFACT, "gaugeImplementation()", "0xeda5458a"),
        (V3FACT, "gaugeImplementation()", "0xeda5458a"),
        (VOTER, "votingEscrow()", "0x4f2bfe5b"),
        (VOTER, "v3PoolFactory()", None),
        (VOTER, "v2PoolFactory()", None),
        (VENEST, "supply()", "0x047fc9aa"),
        (VENEST, "totalSupply()", "0x18160ddd"),
        (VENEST, "permanentTotalSupply()", "0x94340b05"),
        (VENEST, "votingPowerTotalSupply()", "0xe1ba0c00"),
        (VENEST, "token()", "0xfc0c546a"),
        (VENEST, "voter()", "0x46c96aac"),
        (NEST, "totalSupply()", "0x18160ddd"),
    ]
    for to, sig, sel in extra:
        if sel is None:
            continue
        calls.append(("eth_call", [{"to": to, "data": sel}, B]))
        meta.append(("core", sig + "@" + to, None))

    # NEST balanceOf for core holders
    holders = {
        "veNEST_proxy": VENEST,
        "veNEST_impl": VENEST_IMPL,
        "Minter": MINTER,
        "Voter": VOTER,
        "0x6652...9e79": ADDR_6652,
    }
    for label, h in holders.items():
        calls.append(("eth_call", [{"to": NEST, "data": "0x70a08231" + pad(h)}, B]))
        meta.append(("nestbal", label + "@" + h, None))

    # Algebra vault + factory balances for top tokens
    for label, t in TOP_TOKENS.items():
        for holder, hname in ((ALG_VAULT, "AlgebraVault"), (ALG_FACTORY, "AlgebraFactory")):
            calls.append(("eth_call", [{"to": t, "data": "0x70a08231" + pad(holder)}, B]))
            meta.append(("algbal", f"{hname}:{label}@{t}", None))

    # sample gauge selectors
    for sig, sel in (("stakingToken()", "0x72f702f3"), ("rewardToken()", "0xf7c618c1"),
                     ("totalSupply()", "0x18160ddd"), ("feesVault()", "0xc717a86e"),
                     ("ve()", "0x1f850716"), ("gaugeRewarder()", "0x863e2442")):
        calls.append(("eth_call", [{"to": GAUGE_IMPL_PROBE, "data": sel}, B]))
        meta.append(("gauge_probe", sig, None))
    calls.append(("eth_getCode", [GAUGE_IMPL_PROBE, B]))
    meta.append(("gauge_probe", "code", None))

    results = batch(calls, chunk=20)

    per_pool = {}
    core = {}
    nestbal = {}
    algbal = {}
    gauge_probe = {}
    for (kind, key, _), res in zip(meta, results):
        if kind == "code":
            per_pool.setdefault(key, {})["code_size"] = (len(res) - 2) // 2 if res and res != "0x" else 0
        elif kind == "poolToGauge_voter":
            per_pool.setdefault(key, {})["poolToGauge"] = ("0x" + res[-40:]) if res and res != "0x" else None
        elif kind == "getVaultForPool":
            per_pool.setdefault(key, {})["feesVault"] = ("0x" + res[-40:]) if res and res != "0x" else None
        elif kind == "core":
            core[key] = int(res, 16) if res and res != "0x" else None
        elif kind == "nestbal":
            nestbal[key] = int(res, 16) if res and res != "0x" else None
        elif kind == "algbal":
            algbal[key] = int(res, 16) if res and res != "0x" else None
        elif kind == "gauge_probe":
            if key == "code":
                gauge_probe["code_size"] = (len(res) - 2) // 2 if res and res != "0x" else 0
            elif res and len(res) >= 42:
                gauge_probe[key] = "0x" + res[-40:]
            else:
                gauge_probe[key] = int(res, 16) if res and res != "0x" else None

    out["per_pool"] = per_pool
    out["core"] = core
    out["nest_balances"] = nestbal
    out["algebra_balances"] = algbal
    out["gauge_probe"] = gauge_probe

    json.dump(out, open("/home/heisenberg/CA/hyperevm-residuals/analysis/nest_probe1.json", "w"), indent=1)

    # summary print
    ncode = sum(1 for a, v in per_pool.items() if v.get("code_size", 0) > 0)
    print("pools with code:", ncode, "/", len(per_pool))
    mismatch = 0
    for p in pools:
        a = p["id"]
        g_api = (p.get("gauge") or "").lower()
        g_chain = (per_pool.get(a, {}).get("poolToGauge") or "").lower()
        if g_api and g_api != g_chain:
            mismatch += 1
            print("  gauge mismatch", a, "api", g_api, "chain", g_chain)
    print("gauge mismatches:", mismatch)
    nvault = sum(1 for a, v in per_pool.items() if v.get("feesVault") and int(v["feesVault"], 16) != 0)
    print("pools with fees vault:", nvault)
    print("core:", json.dumps(core, indent=1))
    print("nest_balances:", json.dumps(nestbal, indent=1))
    print("gauge_probe:", json.dumps(gauge_probe, indent=1))
    print("algebra_balances:", json.dumps(algbal, indent=1))
    # distinct fees vaults
    vaults = sorted({v["feesVault"] for v in per_pool.values() if v.get("feesVault") and int(v["feesVault"], 16) != 0})
    print("distinct fees vaults:", len(vaults))
    print(json.dumps(vaults, indent=1))


if __name__ == "__main__":
    main()
