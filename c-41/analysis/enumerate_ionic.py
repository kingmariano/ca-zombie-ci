#!/usr/bin/env python3
"""Read-only enumerator for Ionic Protocol (Compound fork) comptrollers.

Usage:
  python3 enumerate_ionic.py <chain> <comptroller> [account,account,...] [--out FILE]

Writes a JSON state dump. No transactions. Uses batched eth_call at latest.
"""
import json
import os
import sys
import time

from rpc import RPC

_DRPC = os.environ.get("DRPC_API_KEY", "")
CHAINS = {
    "mode": f"https://lb.drpc.org/ogrpc?network=mode&dkey={_DRPC}" if _DRPC else "https://mainnet.mode.network",
    "base": f"https://lb.drpc.org/ogrpc?network=base&dkey={_DRPC}" if _DRPC else "https://mainnet.base.org",
    "op": f"https://lb.drpc.org/ogrpc?network=optimism&dkey={_DRPC}" if _DRPC else "https://mainnet.optimism.io",
    "lisk": f"https://lb.drpc.org/ogrpc?network=lisk&dkey={_DRPC}" if _DRPC else "https://rpc.api.lisk.com",
}

COMPTROLLER_GLOBALS = [
    ("oracle()(address)", ()),
    ("admin()(address)", ()),
    ("pendingAdmin()(address)", ()),
    ("ionicAdmin()(address)", ()),
    ("adminHasRights()(bool)", ()),
    ("ionicAdminHasRights()(bool)", ()),
    ("pauseGuardian()(address)", ()),
    ("_mintGuardianPaused()(bool)", ()),
    ("_borrowGuardianPaused()(bool)", ()),
    ("transferGuardianPaused()(bool)", ()),
    ("seizeGuardianPaused()(bool)", ()),
    ("closeFactorMantissa()(uint256)", ()),
    ("liquidationIncentiveMantissa()(uint256)", ()),
    ("enforceWhitelist()(bool)", ()),
    ("borrowCapGuardian()(address)", ()),
]

MARKET_CALLS = [
    ("underlying()(address)", ()),
    ("symbol()(string)", ()),
    ("name()(string)", ()),
    ("decimals()(uint8)", ()),
    ("getCash()(uint256)", ()),
    ("totalSupply()(uint256)", ()),
    ("totalBorrows()(uint256)", ()),
    ("totalReserves()(uint256)", ()),
    ("totalAdminFees()(uint256)", ()),
    ("totalIonicFees()(uint256)", ()),
    ("exchangeRateCurrent()(uint256)", ()),
    ("exchangeRateStored()(uint256)", ()),
    ("reserveFactorMantissa()(uint256)", ()),
    ("accrualBlockNumber()(uint256)", ()),
    ("borrowIndex()(uint256)", ()),
    ("interestRateModel()(address)", ()),
    ("initialExchangeRateMantissa()(uint256)", ()),
    ("comptroller()(address)", ()),
    ("ionicAdmin()(address)", ()),
]

COMPTROLLER_MARKET_CALLS = [
    ("markets(address)(bool,uint256)", "market"),
    ("mintGuardianPaused(address)(bool)", "market"),
    ("borrowGuardianPaused(address)(bool)", "market"),
    ("collateralFactorMantissa(address)(uint256)", "market"),
    ("supplyCaps(address)(uint256)", "market"),
    ("borrowCaps(address)(uint256)", "market"),
    ("isDeprecated(address)(bool)", "market"),
]

ACCOUNT_CTOKEN_CALLS = [
    ("balanceOf(address)(uint256)", "account"),
    ("balanceOfUnderlying(address)(uint256)", "account"),
    ("borrowBalanceCurrent(address)(uint256)", "account"),
    ("borrowBalanceStored(address)(uint256)", "account"),
    ("allowance(address,address)(uint256)", "account_zero"),
]

ACCOUNT_COMPTROLLER_CALLS = [
    ("getAssetsIn(address)(address[])", "account"),
    ("getAccountLiquidity(address)(uint256,uint256,uint256)", "account"),
    ("whitelist(address)(bool)", "account"),
    ("suppliers(address)(bool)", "account"),
    ("borrowers(address)(bool)", "account"),
    ("checkMembership(address,address)(bool)", "account_market"),
]


def _is_err(v):
    if isinstance(v, tuple) and len(v) == 2 and str(v[0]).upper() == "ERROR":
        return True
    if isinstance(v, str) and (v.startswith("ERROR") or v.startswith("error")):
        return True
    return False


def run(chain: str, comptroller: str, accounts, out_file=None, max_borrowers=500):
    rpc = RPC(CHAINS.get(chain, chain), batch_size=int(os.environ.get("RPC_BATCH", "3")))
    t0 = time.time()
    block = rpc.block_number()
    state = {
        "chain": chain,
        "comptroller": comptroller,
        "block": block,
        "ts_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    # globals
    specs = [(comptroller, sig, list(args)) for sig, args in COMPTROLLER_GLOBALS]
    vals = rpc.read_many(specs)
    state["globals"] = {}
    for (sig, _), v in zip(COMPTROLLER_GLOBALS, vals):
        state["globals"][sig.split("(")[0]] = v

    # markets list
    mres = rpc.read(comptroller, "getAllMarkets()(address[])")
    if _is_err(mres) or not isinstance(mres, (list, tuple)):
        state["markets_error"] = str(mres)[:200]
        markets = []
    else:
        markets = [
            str(m) for m in mres if isinstance(m, str) and m.startswith("0x") and len(m) == 42
        ]
        if len(markets) != len(mres):
            state["markets_dropped"] = len(mres) - len(markets)
    state["markets_count"] = len(markets)

    # borrowers: count via getAllBorrowersCount() when available; read a small sample only
    cnt = rpc.read(comptroller, "getAllBorrowersCount()(uint256)")
    if isinstance(cnt, tuple):
        cnt = cnt[0]
    if isinstance(cnt, str) and cnt.startswith("ERROR"):
        cnt = None
    sample_n = int(os.environ.get("BORROWER_SAMPLE", "3"))
    borrowers = []
    for i in range(sample_n):
        v = rpc.read(comptroller, "allBorrowers(uint256)(address)", [i])
        if isinstance(v, tuple):
            v = v[0]
        if isinstance(v, str) and not v.startswith("ERROR"):
            borrowers.append(v)
    state["allBorrowers_count"] = cnt if cnt is not None else len(borrowers)
    state["allBorrowers_sample"] = borrowers
    state["allBorrowers"] = borrowers

    # oracle
    oracle = state["globals"].get("oracle")
    state["oracle_prices"] = {}
    if oracle and not _is_err(oracle):
        ospecs = [(oracle, "getUnderlyingPrice(address)(uint256)", [m]) for m in markets]
        ovals = rpc.read_many(ospecs)
        state["oracle_prices"] = {m: v for m, v in zip(markets, ovals)}
        state["oracle_meta"] = {}
        for sig in [
            "admin()(address)",
            "owner()(address)",
            "pendingAdmin()(address)",
        ]:
            state["oracle_meta"][sig.split("(")[0]] = rpc.read(oracle, sig)

    # per-market
    market_states = []
    for m in markets:
        ms = {"address": m}
        specs = [(m, sig, list(args)) for sig, args in MARKET_CALLS]
        specs += [(comptroller, sig, [m]) for sig, _ in COMPTROLLER_MARKET_CALLS]
        vals = rpc.read_many(specs)
        for (sig, _), v in zip(MARKET_CALLS, vals[: len(MARKET_CALLS)]):
            ms[sig.split("(")[0]] = v
        for (sig, _), v in zip(COMPTROLLER_MARKET_CALLS, vals[len(MARKET_CALLS):]):
            ms[sig.split("(")[0]] = v
        ms["oracle_price"] = state["oracle_prices"].get(m)
        # underlying balance actually held by market contract
        u = ms.get("underlying")
        if isinstance(u, str) and u.startswith("0x") and not u.startswith("ERROR"):
            ms["underlying_balanceOf_market"] = rpc.read(u, "balanceOf(address)(uint256)", [m])
        market_states.append(ms)
    state["markets"] = market_states

    # accounts
    state["accounts"] = {}
    for acct in accounts:
        acc = {"address": acct}
        cspecs = []
        for sig, kind in ACCOUNT_CTOKEN_CALLS:
            for m in markets:
                if kind == "account":
                    cspecs.append((m, sig, [acct]))
                elif kind == "account_zero":
                    cspecs.append((m, sig, [acct, "0x0000000000000000000000000000000000000000"]))
        cvals = rpc.read_many(cspecs)
        idx = 0
        for sig, kind in ACCOUNT_CTOKEN_CALLS:
            acc[sig.split("(")[0]] = {}
            for m in markets:
                acc[sig.split("(")[0]][m] = cvals[idx]
                idx += 1
        # comptroller-level account calls
        for sig, kind in ACCOUNT_COMPTROLLER_CALLS:
            if kind == "account":
                acc[sig.split("(")[0]] = rpc.read(comptroller, sig, [acct])
            elif kind == "account_market":
                acc[sig.split("(")[0]] = {}
                for m in markets:
                    acc[sig.split("(")[0]][m] = rpc.read(comptroller, sig, [acct, m])
        state["accounts"][acct] = acc

    state["elapsed_s"] = round(time.time() - t0, 1)
    if out_file:
        with open(out_file, "w") as f:
            json.dump(state, f, indent=1, default=str)
    return state


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = None
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    chain, comptroller = args[0], args[1]
    accounts = args[2].split(",") if len(args) > 2 and args[2] else []
    st = run(chain, comptroller, accounts, out)
    # brief stdout summary
    print(json.dumps({k: st[k] for k in ["chain", "comptroller", "block", "markets_count", "allBorrowers_count", "elapsed_s"]}, indent=1))
    print("globals:", json.dumps(st["globals"], indent=1, default=str))


if __name__ == "__main__":
    main()
