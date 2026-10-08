#!/usr/bin/env python3
"""Comprehensive read-only state dump for Kinetic (Flare) comptrollers/markets/oracle.
Batches eth_calls over JSON-RPC. Saves analysis/state.json + prints a table.
"""
import json, os, sys, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = [
    "https://14.rpc.thirdweb.com",
    "https://rpc.ankr.com/flare",
    "https://flare.public-rpc.com",
]

C1 = "0x15F69897E6aEBE0463401345543C26d1Fd994abB"
C2 = "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8"

def sel(sig):
    return keccak(text=sig)[:4].hex()

# (label, to, sig, argtypes, argvals, rettypes)
def build_calls(block):
    calls = []
    def add(label, to, sig, atypes, avals, rtypes):
        data = "0x" + sel(sig) + (abi_encode(atypes, avals).hex() if atypes else "")
        calls.append({"label": label, "to": to, "data": data, "rtypes": rtypes})

    for ci, C in enumerate([C1, C2], 1):
        add(f"c{ci}.oracle", C, "oracle()", [], [], ["address"])
        add(f"c{ci}.admin", C, "admin()", [], [], ["address"])
        add(f"c{ci}.pendingAdmin", C, "pendingAdmin()", [], [], ["address"])
        add(f"c{ci}.pauseGuardian", C, "pauseGuardian()", [], [], ["address"])
        add(f"c{ci}.closeFactorMantissa", C, "closeFactorMantissa()", [], [], ["uint256"])
        add(f"c{ci}.liquidationIncentiveMantissa", C, "liquidationIncentiveMantissa()", [], [], ["uint256"])
        add(f"c{ci}.liquidatorsWhitelistVerifier", C, "liquidatorsWhitelistVerifier()", [], [], ["address"])
        add(f"c{ci}.borrowCapGuardian", C, "borrowCapGuardian()", [], [], ["address"])
        add(f"c{ci}.transferGuardianPaused", C, "transferGuardianPaused()", [], [], ["bool"])
        add(f"c{ci}.seizeGuardianPaused", C, "seizeGuardianPaused()", [], [], ["bool"])
        add(f"c{ci}.protocolTokenAddress", C, "protocolTokenAddress()", [], [], ["address"])
        add(f"c{ci}.getAllMarkets", C, "getAllMarkets()", [], [], ["address[]"])
    return calls

def rpc_batch(rpc, calls, block, chunk=20):
    out = {i: None for i in range(len(calls))}
    for start in range(0, len(calls), chunk):
        part = calls[start:start+chunk]
        payload = []
        for j, c in enumerate(part):
            payload.append({"jsonrpc": "2.0", "id": start+j, "method": "eth_call",
                            "params": [{"to": c["to"], "data": c["data"]}, hex(block)]})
        last_err = None
        for rpc_try in [rpc] + [x for x in RPCS if x != rpc]:
            try:
                r = requests.post(rpc_try, json=payload, timeout=60)
                r.raise_for_status()
                for item in r.json():
                    out[item["id"]] = item.get("result")
                break
            except Exception as e:
                last_err = e
        else:
            raise last_err
    return out

def decode_ret(hexstr, rtypes):
    if hexstr is None or hexstr in ("0x", "0x0"):
        return None
    try:
        vals = abi_decode(rtypes, bytes.fromhex(hexstr[2:]))
        if len(vals) == 1:
            return vals[0]
        return list(vals)
    except Exception as e:
        return f"DECODE_ERR:{e}:{hexstr[:80]}"

def main():
    # pick first working rpc, get block
    for rpc in RPCS:
        try:
            bn = int(requests.post(rpc, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=20).json()["result"], 16)
            print(f"# using {rpc} block {bn}", file=sys.stderr)
            break
        except Exception:
            bn = None
    if bn is None:
        print("no RPC", file=sys.stderr); sys.exit(1)
    block = bn - 3  # small lag for consistency

    calls = build_calls(block)
    res = rpc_batch(rpc, calls, block)
    state = {"block": block, "rpc": rpc, "comptrollers": {}}

    # first pass: get markets and key addrs
    ckeys = {}
    for i, c in enumerate(calls):
        v = decode_ret(res[i], c["rtypes"])
        state.setdefault("raw", {})[c["label"]] = v
    markets = {}
    for ci, C in enumerate([C1, C2], 1):
        mk = state["raw"][f"c{ci}.getAllMarkets"] or []
        markets[f"c{ci}"] = mk
        state["comptrollers"][f"c{ci}"] = {
            "address": C,
            "oracle": state["raw"][f"c{ci}.oracle"],
            "admin": state["raw"][f"c{ci}.admin"],
            "pendingAdmin": state["raw"][f"c{ci}.pendingAdmin"],
            "pauseGuardian": state["raw"][f"c{ci}.pauseGuardian"],
            "closeFactor": state["raw"][f"c{ci}.closeFactorMantissa"],
            "liqIncentive": state["raw"][f"c{ci}.liquidationIncentiveMantissa"],
            "liquidatorsWhitelistVerifier": state["raw"][f"c{ci}.liquidatorsWhitelistVerifier"],
            "borrowCapGuardian": state["raw"][f"c{ci}.borrowCapGuardian"],
            "transferGuardianPaused": state["raw"][f"c{ci}.transferGuardianPaused"],
            "seizeGuardianPaused": state["raw"][f"c{ci}.seizeGuardianPaused"],
            "protocolTokenAddress": state["raw"][f"c{ci}.protocolTokenAddress"],
            "markets": mk,
        }

    # second pass: markets + oracle + per-market comptroller flags
    calls2 = []
    def add2(label, to, sig, atypes, avals, rtypes):
        data = "0x" + sel(sig) + (abi_encode(atypes, avals).hex() if atypes else "")
        calls2.append({"label": label, "to": to, "data": data, "rtypes": rtypes})

    for ci, C in enumerate([C1, C2], 1):
        for M in markets[f"c{ci}"]:
            ms = M.lower()
            add2(f"{ms}.symbol", M, "symbol()", [], [], ["string"])
            add2(f"{ms}.underlying", M, "underlying()", [], [], ["address"])
            add2(f"{ms}.getCash", M, "getCash()", [], [], ["uint256"])
            add2(f"{ms}.totalSupply", M, "totalSupply()", [], [], ["uint256"])
            add2(f"{ms}.totalBorrows", M, "totalBorrows()", [], [], ["uint256"])
            add2(f"{ms}.totalReserves", M, "totalReserves()", [], [], ["uint256"])
            add2(f"{ms}.exchangeRateStored", M, "exchangeRateStored()", [], [], ["uint256"])
            add2(f"{ms}.borrowIndex", M, "borrowIndex()", [], [], ["uint256"])
            add2(f"{ms}.accrualBlockTimestamp", M, "accrualBlockTimestamp()", [], [], ["uint256"])
            add2(f"{ms}.reserveFactorMantissa", M, "reserveFactorMantissa()", [], [], ["uint256"])
            add2(f"{ms}.protocolSeizeShareMantissa", M, "protocolSeizeShareMantissa()", [], [], ["uint256"])
            add2(f"{ms}.initialExchangeRateMantissa", M, "initialExchangeRateMantissa()", [], [], ["uint256"])
            add2(f"{ms}.interestRateModel", M, "interestRateModel()", [], [], ["address"])
            add2(f"{ms}.admin", M, "admin()", [], [], ["address"])
            add2(f"{ms}.impl", M, "implementation()", [], [], ["address"])
            add2(f"{ms}.approvalAllowList", M, "approvalAllowList()", [], [], ["address"])
            add2(f"{ms}.decimals", M, "decimals()", [], [], ["uint8"])
            add2(f"{ms}.pendingAdmin", M, "pendingAdmin()", [], [], ["address"])
            add2(f"{ms}.comptroller", M, "comptroller()", [], [], ["address"])
            # comptroller flags
            add2(f"{ms}.markets", C, "markets(address)", ["address"], [M], ["bool","uint256","bool"])
            add2(f"{ms}.mintGuardianPaused", C, "mintGuardianPaused(address)", ["address"], [M], ["bool"])
            add2(f"{ms}.borrowGuardianPaused", C, "borrowGuardianPaused(address)", ["address"], [M], ["bool"])
            add2(f"{ms}.borrowCaps", C, "borrowCaps(address)", ["address"], [M], ["uint256"])
            add2(f"{ms}.supplyRewardSpeeds", C, "supplyRewardSpeeds(uint8,address)", ["uint8","address"], [1, M], ["uint256"])
            # oracle price for cToken
            add2(f"{ms}.price", state["comptrollers"][f"c{ci}"]["oracle"], "getUnderlyingPrice(address)", ["address"], [M], ["uint256"])

    res2 = rpc_batch(rpc, calls2, block)
    raw2 = {}
    for i, c in enumerate(calls2):
        raw2[c["label"]] = decode_ret(res2[i], c["rtypes"])
    state["raw"].update(raw2)

    # third pass: underlyings (symbol/decimals), oracle configs, allowlists
    unds = {}
    for ci, C in enumerate([C1, C2], 1):
        for M in markets[f"c{ci}"]:
            u = state["raw"][f"{M.lower()}.underlying"]
            if u and u != "0x0000000000000000000000000000000000000000":
                unds[u] = True
    calls3 = []
    def add3(label, to, sig, atypes, avals, rtypes):
        data = "0x" + sel(sig) + (abi_encode(atypes, avals).hex() if atypes else "")
        calls3.append({"label": label, "to": to, "data": data, "rtypes": rtypes})

    for u in unds:
        add3(f"und.{u}.symbol", u, "symbol()", [], [], ["string"])
        add3(f"und.{u}.decimals", u, "decimals()", [], [], ["uint8"])
        add3(f"und.{u}.totalSupply", u, "totalSupply()", [], [], ["uint256"])
        add3(f"und.{u}.balanceOf_comptroller", u, "balanceOf(address)", ["address"], [C1], ["uint256"])
        # oracle config for underlying
        for ci, C in enumerate([C1, C2], 1):
            OR = state["comptrollers"][f"c{ci}"]["oracle"]
            add3(f"cfg{ci}.{u}", OR, "tokenConfigs(address)", ["address"], [u], ["address","bytes21","uint64","address"])
            add3(f"cfg{ci}.{u}.prices", OR, "assetPrices(address)", ["address"], [u], ["uint256"])
            add3(f"cfg{ci}.{u}.getPrice", OR, "getPrice(address)", ["address"], [u], ["uint256"])
    # native config
    add3("cfg1.native", state["comptrollers"]["c1"]["oracle"], "tokenConfigs(address)", ["address"], ["0x0000000000000000000000000000000000000000"], ["address","bytes21","uint64","address"])
    add3("cfg2.native", state["comptrollers"]["c2"]["oracle"], "tokenConfigs(address)", ["address"], ["0x0000000000000000000000000000000000000000"], ["address","bytes21","uint64","address"])
    add3("cfg1.native.etherPrice", state["comptrollers"]["c1"]["oracle"], "getEtherPrice()", [], [], ["uint256"])
    add3("cfg2.native.etherPrice", state["comptrollers"]["c2"]["oracle"], "getEtherPrice()", [], [], ["uint256"])
    add3("cfg1.ftsoV2", state["comptrollers"]["c1"]["oracle"], "ftsoV2()", [], [], ["address"])
    add3("cfg2.ftsoV2", state["comptrollers"]["c2"]["oracle"], "ftsoV2()", [], [], ["address"])
    # allowlists: liquidator verifier + cToken approval allowlist
    T = "0x00000000000000000000000000000000DeaDBeef"
    for ci, C in enumerate([C1, C2], 1):
        V = state["comptrollers"][f"c{ci}"]["liquidatorsWhitelistVerifier"]
        if V and V != "0x" + "0"*40:
            add3(f"c{ci}.liqAllow.{T}", V, "allowed(address)", ["address"], [T], ["bool"])
            add3(f"c{ci}.liqAllow.zero", V, "allowed(address)", ["address"], ["0x0000000000000000000000000000000000000000"], ["bool"])
    for ci, C in enumerate([C1, C2], 1):
        for M in markets[f"c{ci}"]:
            A = state["raw"][f"{M.lower()}.approvalAllowList"]
            if A and A != "0x" + "0"*40:
                add3(f"{M.lower()}.apprAllow.{T}", A, "allowed(address)", ["address"], [T], ["bool"])
                add3(f"{M.lower()}.apprAllow.zero", A, "allowed(address)", ["address"], ["0x0000000000000000000000000000000000000000"], ["bool"])

    res3 = rpc_batch(rpc, calls3, block)
    for i, c in enumerate(calls3):
        state["raw"][c["label"]] = decode_ret(res3[i], c["rtypes"])

    # fourth pass: FTSO feeds
    calls4 = []
    ftso1 = state["raw"].get("cfg1.ftsoV2")
    ftso2 = state["raw"].get("cfg2.ftsoV2")
    feed_configs = []
    for key, v in state["raw"].items():
        if key.startswith("cfg") and ".assetPrices" not in key and ".getPrice" not in key and ".ftsoV2" not in key and ".etherPrice" not in key:
            parts = key.split(".")
            if len(parts) == 2 and v and v[1]:
                feed_configs.append((key, v[1]))  # feedId
    feeds = sorted(set(f for _, f in feed_configs))
    for f in feeds:
        for ft in {ftso1, ftso2}:
            if ft and ft != "0x" + "0"*40:
                # bytes21 param
                data = "0x" + sel("getFeedById(bytes21)") + abi_encode(["bytes21"], [f]).hex()
                calls4.append({"label": f"feed.{ft}.{f.hex()}", "to": ft, "data": data, "rtypes": ["uint256","int8","uint64"]})
    if calls4:
        res4 = rpc_batch(rpc, calls4, block)
        for i, c in enumerate(calls4):
            state["raw"][c["label"]] = decode_ret(res4[i], c["rtypes"])

    with open(os.path.join(HERE, "state.json"), "w") as fh:
        json.dump(state, fh, indent=2, default=str)

    # summary table
    print(f"# STATE at block {block}")
    for ci, C in enumerate([C1, C2], 1):
        cmp = state["comptrollers"][f"c{ci}"]
        print(f"\n=== Comptroller c{ci} {C} ===")
        print(f"oracle={cmp['oracle']} admin={cmp['admin']} pauseGuardian={cmp['pauseGuardian']}")
        print(f"liqWhitelistVerifier={cmp['liquidatorsWhitelistVerifier']} closeFactor={cmp['closeFactor']} liqInc={cmp['liqIncentive']}")
        print(f"transferPaused={cmp['transferGuardianPaused']} seizePaused={cmp['seizeGuardianPaused']}")
        for M in cmp["markets"]:
            ms = M.lower()
            g = state["raw"]
            und = g.get(f"{ms}.underlying")
            us = g.get(f"und.{und}.symbol") if und else None
            ud = g.get(f"und.{und}.decimals") if und else None
            mk = g.get(f"{ms}.markets")
            print(f"  {M} {g.get(ms+'.symbol')} und={und} ({us},{ud}) cash={g.get(ms+'.getCash')} supply={g.get(ms+'.totalSupply')} borrows={g.get(ms+'.totalBorrows')} reserves={g.get(ms+'.totalReserves')} exRate={g.get(ms+'.exchangeRateStored')}")
            print(f"     listed={mk[0] if mk else '?'} cf={mk[1] if mk else '?'} mintPaused={g.get(ms+'.mintGuardianPaused')} borrowPaused={g.get(ms+'.borrowGuardianPaused')} borrowCap={g.get(ms+'.borrowCaps')} price={g.get(ms+'.price')} dec={g.get(ms+'.decimals')} rf={g.get(ms+'.reserveFactorMantissa')} pss={g.get(ms+'.protocolSeizeShareMantissa')}")
            print(f"     allow={g.get(ms+'.approvalAllowList')} impl={g.get(ms+'.impl')} admin={g.get(ms+'.admin')}")

if __name__ == "__main__":
    main()
