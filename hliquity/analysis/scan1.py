#!/usr/bin/env python3
"""HLiquity live-state scanner #1 — troves, pools, price, tokens. Public RPC only."""
import json
from eth_utils import keccak, to_checksum_address
from eth_abi import encode
from rpc import rpc_batch

TM   = "0x00000000000000000000000000000000005c9f66"  # TroveManager 0.0.6070118
SP   = "0x00000000000000000000000000000000005c9F5c"  # StabilityPool
AP   = "0x00000000000000000000000000000000005c9f0b"  # ActivePool
DP   = "0x00000000000000000000000000000000005c9F19"  # DefaultPool
PF   = "0x00000000000000000000000000000000005c9F42"  # PriceFeed
ST   = "0x00000000000000000000000000000000005c9f30"  # Staking
HCHF = "0x00000000000000000000000000000000005c9f6a"  # HCHF token contract 0.0.6070122
HLQT = "0x00000000000000000000000000000000005c9f70"  # HLQT HTS token 0.0.6070128
SORT = "0x00000000000000000000000000000000005c9F49"  # SortedTroves

def sel(sig):
    return "0x" + keccak(text=sig)[:4].hex()

def enc(sig, *args, types):
    return sel(sig) + encode(types, args).hex()

def main():
    calls, meta = [], []
    def add(label, to, sig, types=(), *args):
        calls.append(("eth_call", [{"to": to, "data": enc(sig, *args, types=types)}, "latest"]))
        meta.append(label)

    # price first
    add("pf.fetchPrice", PF, "fetchPrice()")
    add("pf.lastGoodPrice", PF, "lastGoodPrice()")
    r = rpc_batch(calls)
    price = int(r[0], 16); lastgood = int(r[1], 16)
    print("fetchPrice =", price, " lastGoodPrice =", lastgood)

    add("tm.troveCount", TM, "getTroveOwnersCount()")
    n = int(rpc_batch(calls[-1:])[0], 16)
    print("troveCount =", n)

    for i in range(n):
        add(f"tm.owner{i}", TM, "getTroveFromTroveOwnersArray(uint256)", ("uint256",), i)
    res = rpc_batch(calls[-n:])
    owners = ["0x" + x[-40:] for x in res]
    print("owners:", owners)

    for i, o in enumerate(owners):
        add(f"trove{i}.debt", TM, "getTroveDebt(address)", ("address",), o)
        add(f"trove{i}.coll", TM, "getTroveColl(address)", ("address",), o)
        add(f"trove{i}.status", TM, "getTroveStatus(address)", ("address",), o)
        add(f"trove{i}.icr", TM, "getCurrentICR(address,uint256)", ("address", "uint256"), o, price)
        add(f"trove{i}.nicr", TM, "getNominalICR(address)", ("address",), o)
    add("tm.entireColl", TM, "getEntireSystemColl()")
    add("tm.entireDebt", TM, "getEntireSystemDebt()")
    add("tm.getTCR", TM, "getTCR(uint256)", ("uint256",), price)
    add("tm.recoveryMode", TM, "checkRecoveryMode(uint256)", ("uint256",), price)
    add("tm.baseRate", TM, "baseRate()")
    add("tm.redemptionRate", TM, "getRedemptionRate()")
    add("tm.lastFeeOp", TM, "lastFeeOperationTime()")
    add("tm.totalStakes", TM, "totalStakes()")
    add("tm.getLastZombieTrove", TM, "getLastZombieTrove()(address)")
    # stability pool
    add("sp.totalDeposits", SP, "getTotalHCHFDeposits()")
    add("sp.totalHCHFGains", SP, "getTotalHCHFGains()")
    add("sp.totalHLQTGains", SP, "getTotalHLQTGains()")
    # active pool
    add("ap.hbar", AP, "getHBAR()")
    add("ap.hchfDebt", AP, "getHCHFDebt()")
    # default pool
    add("dp.hbar", DP, "getHBAR()")
    add("dp.hchfDebt", DP, "getHCHFDebt()")
    # sorted troves
    add("sort.size", SORT, "getSize()")
    add("sort.first", SORT, "getFirst()(address)")
    add("sort.last", SORT, "getLast()(address)")
    # HCHF token
    for f in ["name()", "symbol()", "decimals()", "totalSupply()",
              "troveManager()(address)", "stabilityPool()(address)", "borrowerOperations()(address)", "owner()(address)"]:
        add("hchf." + f.split("(")[0], HCHF, f)
    # HLQT token (HTS via EVM)
    for f in ["name()", "symbol()", "decimals()", "totalSupply()", "owner()(address)"]:
        add("hlqt." + f.split("(")[0], HLQT, f)
    # staking
    for f in ["totalHLQTStaked()", "totalLQTYStaked()", "owner()(address)",
              "F_HBAR()", "F_HLQT()", "totalHBARGains()"]:
        add("st." + f.split("(")[0], ST, f)

    res = rpc_batch(calls)
    out = {label: r for label, r in zip(meta, res)}
    json.dump({"price": price, "lastGoodPrice": lastgood, "owners": owners, "results": out},
              open("scan1.json", "w"), indent=1)
    for label, r in zip(meta, res):
        if isinstance(r, dict):
            v = f"ERROR {r.get('error', {}).get('message', '')[:70]}"
        else:
            try:
                v = str(int(r, 16))
            except Exception:
                v = r
        print(f"{label:26s} {v}")

if __name__ == "__main__":
    main()
