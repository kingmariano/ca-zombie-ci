#!/usr/bin/env python3
"""Precise optimization of the STC->FAI->liquidation arbitrage + capital sensitivity."""
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
STC = "0x1::STC::STC"
FAI = "0x4ffcc98f43ce74668264a0cf6eebe42b::FAI::FAI"
X = 410813790911242
Y = 21413902183198

def quote(dx):
    out = view(f"{DEX}::TokenSwapLibrary::get_amount_out", [f"{dx}u128", f"{X}u128", f"{Y}u128", "3", "1000"])
    return out[0] if isinstance(out, list) else None

def seize(cover_units):
    return (cover_units * 10**8) // (10000 * 90)

def profit_onchain(dx):
    f = quote(dx)
    if f is None: return None
    return seize(f) - dx, f

# fine golden-section-ish search on the exact on-chain quote
def f_p(dx):
    r = profit_onchain(dx)
    return r[0] if r else -1

lo, hi = 1, X
best_dx = 0; best = -1
# coarse scan
N = 4000
for i in range(1, N):
    dx = lo + (hi - lo) * i // N
    p = f_p(dx)
    if p > best:
        best, best_dx = p, dx
# refine around best
span = (hi - lo) // N
for _ in range(6):
    for k in range(-50, 51):
        dx = best_dx + span * k // 50
        if dx <= 0 or dx >= X: continue
        p = f_p(dx)
        if p > best:
            best, best_dx = p, dx
    span = max(1, span // 50)

f_best = quote(best_dx)
print(f"OPTIMAL (exact on-chain quotes): spend {best_dx/1e9:,.4f} STC -> {f_best/1e9:,.4f} FAI -> seize {seize(f_best)/1e9:,.4f} STC")
print(f"  net profit = {best/1e9:,.4f} STC = {best/best_dx:.4f}x")
print(f"  USD@market(0.00011112) = ${best/1e9*0.00011112:,.2f}")
print(f"  USD@oracle(0.01)       = ${best/1e9*0.01:,.2f}")

print("\ncapital sensitivity (profit vs STC spent):")
for dx in [1_000_00000000, 10_000_00000000, 50_000_00000000, 100_000_00000000,
           200_000_00000000, 421_022_514000000, 600_000_00000000, 1_000_000_00000000]:
    r = profit_onchain(dx)
    if r:
        p, f = r
        print(f"  spend {dx/1e9:>14,.0f} STC -> {f/1e9:>12,.2f} FAI -> seize {seize(f)/1e9:>14,.0f} -> net {p/1e9:>12,.0f} STC ({p/dx:.2f}x) = ${p/1e9*0.00011112:,.2f}@market")

# exit liquidity
resx = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, "0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT"])
print("\nSTC/XUSDT exit pool reserves:", resx)
if isinstance(resx, list):
    stc_r, xusdt_r = resx
    # max XUSDT obtainable by dumping all profit STC
    dx = best  # sell `best` STC units
    out = view(f"{DEX}::TokenSwapLibrary::get_amount_out", [f"{dx}u128", f"{stc_r}u128", f"{xusdt_r}u128", "3", "1000"])
    if isinstance(out, list):
        print(f"  dumping {dx/1e9:,.0f} STC -> {out[0]/1e6:.6f} XUSDT (pool only holds {xusdt_r/1e6:.4f} XUSDT)")
