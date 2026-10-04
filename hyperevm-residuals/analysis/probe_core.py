#!/usr/bin/env python3
"""Batched probe of Nest + Hybra core contracts on HyperEVM."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

NEST = {
    "NEST_token": "0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035",
    "veNEST_proxy": "0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074",
    "Voter_proxy": "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901",
    "PairFactory_proxy": "0x889Fd0aDA8453C7619cD7f11E9029a1f0848Fdf5",
    "Minter_proxy": "0x574f6865140e6929bDed24596D78a8D9c07E356d",
    "GaugeFactoryV2_proxy": "0x15eb3987A7edC464e5A4d3bC3A9b8E84b8ceE2C7",
    "GaugeFactoryV3_proxy": "0x09D1A533032319557196F87dFf831FF46204c49d",
    "FeesVaultFactory_proxy": "0x705C76e29977Ed52cd93d390A7BBcC61189724C0",
    "BribeFactory_proxy": "0x638e382300Ee2ece790164DAfAF7a9f16045621b",
    "AlgebraFactory": "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3",
    "AlgebraVault": "0x15E408A37cE4D13218202C0054B0f485E38F5768",
    "SwapRouter": "0xaA26B8e5Cadd04430c32787eCC3AA325e99681e9",
    "NonfungiblePositionManager": "0xEAF58788a405F3253814b4559391a22bE8616250",
    "RouterV2": "0xfDb34624506e9A0624AF60F85ebd9E44A0FD2a17",
    "ProxyAdmin": "0xb688d5e73777DfaaDbD7c5Fe98Aee6F35CF20124",
    "ManagedNFTManager_proxy": "0x843d31e601b38F7207864457f0fB38E14441E792",
    "VeNestDistributor_proxy": "0x22350F14c6ee70992f1bbc7498e4C291B8B7682f",
    "NestRaise_proxy": "0xcd78D1A27320FeE9A03860172649b92A10aA3867",
}

HYBRA = {
    "V4_factory(adapter)": "0x32b9dA73215255d50D84FeB51540B75acC1324c2",
}

GETTERS = ["owner()", "allPairsLength()", "allPoolsLength()", "numPools()", "length()", "minter()", "veNEST()", "totalWeight()", "activePeriod()", "totalSupply()"]

if __name__ == "__main__":
    bn = block_number()
    print("block:", bn)
    calls = []
    meta = []
    for group, d in [("NEST", NEST), ("HYBRA", HYBRA)]:
        for name, addr in d.items():
            calls.append(("eth_getCode", [addr, hex(bn)]))
            meta.append((group, name, addr, "code"))
            for g in GETTERS:
                calls.append(("eth_call", [{"to": addr, "data": enc_sel(g)}, hex(bn)]))
                meta.append((group, name, addr, g))
    results = batch(calls)
    out = {}
    for (group, name, addr, kind), res in zip(meta, results):
        key = f"{group}:{name}"
        if key not in out:
            out[key] = {"address": addr}
        if kind == "code":
            out[key]["code_size"] = (len(res) - 2) // 2 if res and res != "0x" else 0
        else:
            if res and res != "0x":
                out[key][kind] = int(res, 16) if len(res) <= 66 else res
    print(json.dumps(out, indent=1))
