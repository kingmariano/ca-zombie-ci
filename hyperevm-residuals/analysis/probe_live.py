#!/usr/bin/env python3
"""Batched live-state probe of Nest core (HyperEVM 999), read-only.
All calls collected then batched (25/batch) for speed.
"""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc2 import *

C = {
    "NEST": "0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035",
    "veNEST": "0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074",
    "Voter": "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901",
    "Minter": "0x574f6865140e6929bDed24596D78a8D9c07E356d",
    "GaugeFactoryV2": "0x15eb3987A7edC464e5A4d3bC3A9b8E84b8ceE2C7",
    "GaugeFactoryV3": "0x09D1A533032319557196F87dFf831FF46204c49d",
    "GaugeRewarder": "0xfF0124cf664240e5573282511042d7033C3f22eA",
    "FeesVaultFactory": "0x705C76e29977Ed52cd93d390A7BBcC61189724C0",
    "BribeFactory": "0x638e382300Ee2ece790164DAfAF7a9f16045621b",
    "ManagedNFTManager": "0x843d31e601b38F7207864457f0fB38E14441E792",
    "CompoundStrategyFactory": "0x98fe2510DFcAdb52431C2A651E1ecfC46196fa87",
    "CompoundEmissionExtension": "0x1c925056A1a657a4cb70D677D8C21028233cA05D",
    "VeNestDistributor": "0x22350F14c6ee70992f1bbc7498e4C291B8B7682f",
    "NestRaise": "0xcd78D1A27320FeE9A03860172649b92A10aA3867",
    "VeNestSplitMerklAirdrop": "0xB97B9217B55F322F7105f34777Af9F63B3b720A6",
    "PairFactoryV2": "0x889Fd0aDA8453C7619cD7f11E9029a1f0848Fdf5",
    "AlgebraFactory": "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3",
    "CLVault": "0x15E408A37cE4D13218202C0054B0f485E38F5768",
    "RouterV2": "0xfDb34624506e9A0624AF60F85ebd9E44A0FD2a17",
    "ProxyAdmin": "0xb688d5e73777DfaaDbD7c5Fe98Aee6F35CF20124",
    "CLProxyAdmin": "0x45727c03B46970C64E4039B546E6bd1F9c9d92ab",
}

U256_COMMON = ["owner()", "totalSupply()", "pendingOwner()"]
U256 = {
    "veNEST": ["supply()", "epoch()", "permanentTotalSupply()", "lastMintedTokenId()"],
    "Voter": ["epochTimestamp()", "votingPaused()", "voteDelay()", "distributionWindowDuration()", "index()"],
    "Minter": ["weekly()", "active_period()", "isStarted()", "isFirstMint()", "teamRate()", "decayRate()",
               "inflationRate()", "lastInflationPeriod()", "startEmissionDistributionTimestamp()", "epochEmissionAdjustmentBps()"],
    "GaugeRewarder": ["totalRewardClaimed()"],
    "FeesVaultFactory": [],
    "ManagedNFTManager": [],
    "VeNestDistributor": ["startTime()", "endTime()", "isClaimActive()", "startEmissionDistributionTimestamp()"],
    "NestRaise": ["startTime()", "endTime()", "claimStart()", "claimEnd()"],
    "VeNestSplitMerklAirdrop": ["startTime()", "endTime()"],
    "AlgebraFactory": [],
}
ADDR = {
    "veNEST": ["artProxy()", "veBoost()", "managedNFTManager()", "customBribeRewardRouter()", "voter()", "token()"],
    "Voter": ["minter()", "bribeFactory()", "v2PoolFactory()", "v3PoolFactory()", "v2GaugeFactory()", "v3GaugeFactory()",
              "gaugeRewarder()", "managedNFTManager()", "veNestMerklAidrop()", "compoundEmissionExtension()", "votingEscrow()", "token()"],
    "Minter": ["voter()", "ve()", "nest()"],
    "GaugeFactoryV2": ["gaugeImplementation()", "last_gauge()", "merklGaugeMiddleman()", "voter()"],
    "GaugeFactoryV3": ["gaugeImplementation()", "last_gauge()", "merklGaugeMiddleman()", "voter()"],
    "GaugeRewarder": ["signer()", "token()", "gaugeOwner()"],
    "FeesVaultFactory": ["owner()"],
    "BribeFactory": ["owner()"],
    "ManagedNFTManager": ["voter()", "votingEscrow()", "ve()", "strategyFactory()", "nftManager()", "owner()"],
    "CompoundStrategyFactory": ["voter()", "owner()"],
    "CompoundEmissionExtension": ["voter()", "votingEscrow()", "ve()", "owner()"],
    "VeNestDistributor": ["veNEST()", "owner()", "token()"],
    "NestRaise": ["owner()", "token()"],
    "VeNestSplitMerklAirdrop": ["voter()", "owner()", "veNEST()"],
    "PairFactoryV2": ["owner()"],
    "AlgebraFactory": ["owner()", "poolDeployer()", "vaultFactory()", "defaultBasePluginFactory()"],
    "CLVault": ["owner()", "factory()", "communityFeeManager()"],
    "RouterV2": ["owner()"],
    "ProxyAdmin": ["owner()"],
    "CLProxyAdmin": ["owner()"],
}


def main():
    bn = block_number()
    print("block", bn)
    calls = []
    meta = []

    def add(name, kind, to, sig, args=()):
        calls.append(("eth_call", [{"to": to, "data": enc_sel(sig) + enc_args(args)}, hex(bn)]))
        meta.append((name, kind, to, sig))

    for name, a in C.items():
        for sig in U256_COMMON + U256.get(name, []):
            add(name, "u256", a, sig)
        for sig in ADDR.get(name, []):
            add(name, "addr", a, sig)
        calls.append(("eth_getBalance", [a, hex(bn)]))
        meta.append((name, "native", a, ""))
    # NEST balances of core contracts
    for name, a in C.items():
        if a.lower() == "0x" + "0" * 40:
            continue
        calls.append(("eth_call", [{"to": C["NEST"], "data": enc_sel("balanceOf(address)") + enc_args((int(a, 16),))}, hex(bn)]))
        meta.append((name, "nestbal", C["NEST"], "balanceOf(address)"))
    # code sizes
    for name, a in C.items():
        calls.append(("eth_getCode", [a, hex(bn)]))
        meta.append((name, "code", a, ""))
    res = batch(calls)
    out = {"block": bn}

    def words(hexstr):
        if not hexstr or hexstr == "0x":
            return None
        b = bytes.fromhex(hexstr[2:])
        return [int.from_bytes(b[i:i + 32], "big") for i in range(0, len(b), 32)]

    for (name, kind, a, sig), r in zip(meta, res):
        d = out.setdefault(name, {"address": a})
        if kind == "u256":
            w = words(r)
            if w:
                d[sig] = w[-1]
        elif kind == "addr":
            if r and r != "0x" and len(r) >= 42:
                d[sig] = "0x" + r[-40:]
        elif kind == "native":
            d["native_wei"] = int(r, 16) if r else 0
        elif kind == "nestbal":
            w = words(r)
            if w:
                d = out.setdefault("NEST_balance", {})
                d[name] = w[-1]
        elif kind == "code":
            d["code_size"] = (len(r) - 2) // 2 if r and r != "0x" else 0

    # pools
    v = C["Voter"]
    # poolsCounts returns 3 words; read raw and split
    raw = eth_call(v, enc_sel("poolsCounts()"), hex(bn))
    w = words(raw) or [0, 0, 0]
    out["poolsCounts"] = {"total": w[0], "v2": w[1], "v3": w[2], "raw": raw}
    total = w[0]
    pools = []
    if 0 < total <= 200:
        calls = []
        for i in range(total):
            calls.append(("eth_call", [{"to": v, "data": enc_sel("pools(uint256)") + enc_args((i,))}, hex(bn)]))
        for r in batch(calls):
            if r and r != "0x" and len(r) >= 42:
                pools.append("0x" + r[-40:])
    out["pools"] = pools
    pinfo = {}
    calls = []
    meta = []
    for p in pools:
        calls.append(("eth_call", [{"to": v, "data": enc_sel("poolToGauge(address)") + enc_args((int(p, 16),))}, hex(bn)]))
        meta.append((p, "gauge"))
    gauges = []
    for (p, kind), r in zip(meta, batch(calls)):
        g = "0x" + r[-40:] if r and r != "0x" and len(r) >= 42 else None
        pinfo[p] = {"gauge": g}
        if g:
            gauges.append((p, g))
    calls = []
    meta = []
    for p, g in gauges:
        calls.append(("eth_call", [{"to": v, "data": enc_sel("gaugesState(address)") + enc_args((int(g, 16),))}, hex(bn)]))
        meta.append((p, g, "state"))
        for sig in ["rewardRate()", "periodFinish()", "totalSupply()", "feeVault()", "TOKEN()", "isDistributeEmissionToMerkle()", "internal_bribe()", "external_bribe()"]:
            calls.append(("eth_call", [{"to": g, "data": enc_sel(sig)}, hex(bn)]))
            meta.append((p, g, sig))
        for sig in ["token0()", "token1()"]:
            calls.append(("eth_call", [{"to": p, "data": enc_sel(sig)}, hex(bn)]))
            meta.append((p, g, "pool:" + sig))
        calls.append(("eth_call", [{"to": p, "data": enc_sel("symbol()")}, hex(bn)]))
        meta.append((p, g, "pool:symbol"))
        calls.append(("eth_call", [{"to": p, "data": enc_sel("communityVault()")}, hex(bn)]))
        meta.append((p, g, "pool:communityVault"))
    for (p, g, kind), r in zip(meta, batch(calls)):
        d = pinfo.setdefault(p, {})
        if kind == "state":
            w = words(r)
            if w and len(w) >= 8:
                d["gaugeState"] = {
                    "isGauge": bool(w[0]), "isAlive": bool(w[1]),
                    "internalBribe": "0x" + w[2].to_bytes(32, "big")[-20:].hex(),
                    "externalBribe": "0x" + w[3].to_bytes(32, "big")[-20:].hex(),
                    "pool": "0x" + w[4].to_bytes(32, "big")[-20:].hex(),
                    "claimable": w[5], "index": w[6], "lastDistribution": w[7],
                }
        elif kind.startswith("pool:"):
            if kind == "pool:symbol":
                d["symbol"] = call_str_decode(r)
            elif kind == "pool:communityVault":
                if r and r != "0x" and len(r) >= 42:
                    d["communityVault"] = "0x" + r[-40:]
            else:
                w = words(r)
                if w:
                    d[kind] = w[-1]
        else:
            w = words(r)
            if w:
                d["gauge:" + kind] = w[-1]
    out["pool_info"] = pinfo
    json.dump(out, open("/home/heisenberg/CA/hyperevm-residuals/analysis/nest_live_state.json", "w"), indent=1)
    print(json.dumps(out, indent=1))


def call_str_decode(out):
    if not out or out == "0x":
        return None
    b = bytes.fromhex(out[2:])
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode(errors="replace")
    except Exception:
        return None


if __name__ == "__main__":
    main()
