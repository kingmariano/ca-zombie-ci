#!/usr/bin/env python3
"""Enumerate Hybra V4 CL pools + measure token balances; probe core addresses."""
import sys, json, datetime
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

F = "0x32b9dA73215255d50D84FeB51540B75acC1324c2"

def main():
    bn = block_number()
    print("block", bn)
    n = int(eth_call(F, enc_sel("allPoolsLength()")), 16)
    print("allPoolsLength:", n)
    # core getters
    for sig in ["owner()", "gaugeManager()", "poolImplementation()", "defaultProtocolFee()", "MAX_FEE()", "protocolFeeManager()", "swapFeeManager()", "unstakedFeeManager()", "swapFeeModule()", "protocolFeeModule()", "unstakedFeeModule()"]:
        try:
            out = eth_call(F, enc_sel(sig), hex(bn))
            v = int(out, 16)
            if sig in ("owner()", "gaugeManager()", "poolImplementation()", "protocolFeeManager()", "swapFeeManager()", "unstakedFeeManager()", "swapFeeModule()", "protocolFeeModule()", "unstakedFeeModule()"):
                print(sig, "0x%040x" % v)
            else:
                print(sig, v)
        except Exception as e:
            print(sig, "ERR", str(e)[:80])
    # all pools
    calls, meta = [], []
    for i in range(n):
        calls.append(("eth_call", [{"to": F, "data": enc_sel("allPools(uint256)") + f"{i:064x}"}, hex(bn)]))
        meta.append(("pool", i))
    res = batch(calls)
    pools = []
    for (k, i), r in zip(meta, res):
        if r and r != "0x":
            pools.append("0x" + r[-40:])
    print("pools:", len(pools))
    # token0/token1/fee/gauge
    calls, meta = [], []
    for p in pools:
        for sig in ["token0()", "token1()", "fee()", "gauge()", "liquidity()"]:
            calls.append(("eth_call", [{"to": p, "data": enc_sel(sig)}, hex(bn)]))
            meta.append((p, sig))
    res = batch(calls)
    info = {}
    for (p, sig), r in zip(meta, res):
        info.setdefault(p, {})
        if r and r != "0x":
            v = int(r, 16)
            info[p][sig] = ("0x%040x" % v) if sig in ("token0()", "token1()", "gauge()") else v
    out = []
    for p in pools:
        out.append({"pool": p, **info.get(p, {})})
    json.dump(out, open("hybra_pools.json", "w"), indent=1)
    for p in out[:40]:
        print(p)
    print("saved hybra_pools.json; n=", len(out))

if __name__ == "__main__":
    main()
