#!/usr/bin/env python3
"""Query TokenSwap pools (STC/FAI, STC/XUSDT, STC/STAR) + fee config (read-only)."""
import json, urllib.request

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
BF = "0x4ffcc98f43ce74668264a0cf6eebe42b"
STC = "0x1::STC::STC"
FAI = f"{BF}::FAI::FAI"
XUSDT = "0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT"
STAR = f"{DEX}::STAR::STAR"

def getres(addr, typ):
    r = call("contract.get_resource", [addr, typ])
    return r.get("result", r.get("error"))

def reserves(tok_y, label):
    pair = getres(DEX, f"{DEX}::TokenSwap::TokenSwapPair<{STC}, {tok_y}>")
    if not isinstance(pair, dict) or "value" not in pair:
        print(label, "ERR", str(pair)[:200]); return None
    v = dict((k, x) for k, x in pair["value"])
    xr = int(v["token_x_reserve"]["Struct"]["value"][0][1]["U128"])
    yr = int(v["token_y_reserve"]["Struct"]["value"][0][1]["U128"])
    ts = int(v["last_block_timestamp"]["U64"])
    print(f"{label}: STC_reserve={xr/1e9:,.6f} STC | Y_reserve={yr/1e9:,.6f} | last_ts={ts}")
    return {"x": xr, "y": yr, "ts": ts}

r1 = reserves(FAI, "STC/FAI (BFly)")
r2 = reserves(XUSDT, "STC/XUSDT")
r3 = reserves(STAR, "STC/STAR")

if r1:
    print(f"  pool FAI price = {r1['x']/r1['y']:.4f} STC per FAI")
if r2:
    print(f"  STC price in XUSDT = {r2['y']/r2['x']*1e9/1e6:.10f} XUSDT per STC")

# fee configs
for t in ["SwapFeeOperationConfig", "SwapStepwiseMultiplierConfig"]:
    c = getres(DEX, f"0x1::Config::Config<{DEX}::TokenSwapConfig::{t}>")
    print(f"\n=== {t} ===")
    print(json.dumps(c, indent=1)[:1200])
