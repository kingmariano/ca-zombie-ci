#!/usr/bin/env python3
"""DEX freeze switch + swap simulation with correct U128 encoding."""
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

for fn in ["TokenSwapConfig::get_global_freeze_switch", "TokenSwapConfig::get_fee_auto_convert_switch",
           "TokenSwapConfig::get_alloc_mode_upgrade_switch"]:
    print(fn, "=>", view(f"{DEX}::{fn}"))

# Try U128 encoding variants for get_amount_out
for enc in ["1000000000000", {"U128": "1000000000000"}, {"u128": "1000000000000"}]:
    r = view(f"{DEX}::TokenSwapLibrary::get_amount_out", [enc, "410813790911242", "21413902183198", "3", "1000"])
    print("get_amount_out", enc if isinstance(enc, str) else json.dumps(enc), "=>", r)

# compute_y_out via router (type args)
for enc in ["1000000000000", {"U128": "1000000000000"}]:
    r = view(f"{DEX}::TokenSwapRouter::compute_y_out", [enc], [STC, FAI])
    print("compute_y_out", enc if isinstance(enc, str) else json.dumps(enc), "=>", r)

# LP token supply
lp = call("contract.get_resource", [DEX, f"0x1::Token::TokenInfo<{DEX}::TokenSwap::LiquidityToken<{STC}, {FAI}>>"])
print("LP TokenInfo =>", json.dumps(lp.get("result"))[:400])

# XUSDT token supply
xu = call("contract.get_resource", ["0xe52552637c5897a2d499fbf08216f73e", "0x1::Token::TokenInfo<0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT>"])
print("XUSDT TokenInfo =>", json.dumps(xu.get("result"))[:400])

# global STC info: supply
stc = call("contract.get_resource", ["0x1", "0x1::Token::TokenInfo<0x1::STC::STC>"])
print("STC TokenInfo =>", json.dumps(stc.get("result"))[:400])
