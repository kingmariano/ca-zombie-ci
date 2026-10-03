#!/usr/bin/env python3
"""Precise optimization of the STC->FAI->liquidation arbitrage (local exact math + on-chain spot checks)."""
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
X = 410813790911242   # STC reserve
Y = 21413902183198    # FAI reserve

def fai_out(dx):
    return (dx * 997 * Y) // (X * 1000 + dx * 997)

def seize(cover):
    return (cover * 10**8) // (10000 * 90)

def profit(dx):
    return seize(fai_out(dx)) - dx

# local golden-section search (profit is unimodal)
lo, hi = 1, X - 1
for _ in range(200):
    m1 = lo + (hi - lo) // 3
    m2 = hi - (hi - lo) // 3
    if profit(m1) < profit(m2): lo = m1
    else: hi = m2
best_dx = (lo + hi) // 2
best = profit(best_dx)
f_best = fai_out(best_dx)
print(f"OPTIMAL: spend {best_dx/1e9:,.4f} STC -> {f_best/1e9:,.4f} FAI -> seize {seize(f_best)/1e9:,.4f} STC")
print(f"  net profit = {best/1e9:,.4f} STC = {best/best_dx:.4f}x")
print(f"  USD@market(0.00011112) = ${best/1e9*0.00011112:,.2f}")
print(f"  USD@oracle(0.01)       = ${best/1e9*0.01:,.2f}")

# on-chain validation of the local formula
for dx in [best_dx, 421_022_514000000, 10_000_00000000]:
    on = view(f"{DEX}::TokenSwapLibrary::get_amount_out", [f"{dx}u128", f"{X}u128", f"{Y}u128", "3", "1000"])
    on_v = on[0] if isinstance(on, list) else None
    print(f"  validate dx={dx/1e9:,.3f}: local={fai_out(dx)} onchain={on_v} match={on_v==fai_out(dx)}")

print("\ncapital sensitivity:")
for dx in [1_000_00000000, 10_000_00000000, 50_000_00000000, 100_000_00000000,
           200_000_00000000, 421_022_514000000, 600_000_00000000, 1_000_000_00000000]:
    p = profit(dx); f = fai_out(dx)
    print(f"  spend {dx/1e9:>14,.0f} STC -> {f/1e9:>12,.2f} FAI -> seize {seize(f)/1e9:>14,.0f} -> net {p/1e9:>12,.0f} STC ({p/dx:.2f}x) = ${p/1e9*0.00011112:,.2f}@market")

# exit liquidity (single call)
resx = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, "0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT"])
print("\nSTC/XUSDT exit pool reserves:", resx)
if isinstance(resx, list) and len(resx) == 2:
    stc_r, xusdt_r = resx
    out = view(f"{DEX}::TokenSwapLibrary::get_amount_out", [f"{best}u128", f"{stc_r}u128", f"{xusdt_r}u128", "3", "1000"])
    if isinstance(out, list):
        print(f"  dumping {best/1e9:,.0f} STC -> {out[0]/1e6:.6f} XUSDT (pool only holds {xusdt_r/1e6:.4f} XUSDT)")

json.dump({"best_spend_units": best_dx, "best_fai_units": f_best, "best_profit_units": best,
           "seize_units": seize(f_best), "roi": best/best_dx,
           "usd_market": best/1e9*0.00011112, "usd_oracle": best/1e9*0.01},
          open("arb_result.json","w"), indent=1)
print("\nwrote arb_result.json")
