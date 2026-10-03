#!/usr/bin/env python3
"""Simulate the STC -> FAI pool purchase and the liquidate-to-STC arbitrage (read-only)."""
import json, urllib.request

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())
def view(fn, args=[], ta=[]):
    r = call("contract.call_v2", [{"function_id": fn, "args": args, "type_args": ta}])
    return r.get("result", r.get("error"))

DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
BF = "0x4ffcc98f43ce74668264a0cf6eebe42b"
STC = "0x1::STC::STC"
FAI = f"{BF}::FAI::FAI"
XUSDT = "0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT"

# fee rates
pr = view(f"{DEX}::TokenSwapRouter::get_poundage_rate", [], [STC, FAI])
print("get_poundage_rate(STC,FAI) =>", pr)
fr = view(f"{DEX}::TokenSwapRouter::get_swap_fee_operation_rate_v2", [], [STC, FAI])
print("get_swap_fee_operation_rate_v2(STC,FAI) =>", fr)
prx = view(f"{DEX}::TokenSwapRouter::get_poundage_rate", [], [STC, XUSDT])
print("get_poundage_rate(STC,XUSDT) =>", prx)

# reserves via router view
res = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, FAI])
print("get_reserves(STC,FAI) =>", res)
resx = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, XUSDT])
print("get_reserves(STC,XUSDT) =>", resx)

# exact amount_out simulation: get_amount_out(amount_in, reserve_in, reserve_out, fee_num, fee_den)
def amount_out(amount_in, rin, rout, fn_, fd):
    r = view(f"{DEX}::TokenSwapLibrary::get_amount_out", [str(amount_in), str(rin), str(rout), str(fn_), str(fd)])
    return r
if isinstance(pr, list) and len(pr) == 2:
    fn_, fd = pr
    for stc_in in [10_000_00000000, 100_000_00000000, 577_900_00000000]:
        out = amount_out(stc_in, 410813790911242, 21413902183198, fn_, fd)
        print(f"swap {stc_in/1e9:,.0f} STC -> FAI out = {out} ({(out[0] if isinstance(out,list) else 0)/1e9:,.4f} FAI)")
