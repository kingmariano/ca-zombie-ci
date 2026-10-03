#!/usr/bin/env python3
"""Full-cycle arbitrage: XUSDT -> STC -> FAI -> liquidate -> STC -> XUSDT (exact AMM math)."""
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
XUSDT = "0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT"
FAI = "0x4ffcc98f43ce74668264a0cf6eebe42b::FAI::FAI"

# live reserves (fresh)
resA = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, XUSDT])   # [stc, xusdt]
resB = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, FAI])    # [stc, fai]
print("pool A STC/XUSDT:", resA)
print("pool B STC/FAI:  ", resB)
xA, yA = resA; xB, yB = resB

def out(dx, rin, rout):
    return (dx * 997 * rout) // (rin * 1000 + dx * 997)

def seize(cover):
    return (cover * 10**8) // (10000 * 90)

def full_cycle(u):
    """u = XUSDT units spent in pool A; returns final XUSDT units out."""
    stc1 = out(u, yA, xA)                 # buy STC with XUSDT (rin=yA, rout=xA)
    fai = out(stc1, xB, yB)               # buy FAI with STC
    seized = seize(fai)                   # liquidation STC out
    # pool A after step 1
    xA2, yA2 = xA - stc1, yA + u
    xu_out = out(seized, xA2, yA2)        # sell seized STC for XUSDT
    return xu_out, stc1, fai, seized

best = (-1, None)
# scan u from 1 to 4000 XUSDT
step = 10**6  # 1 XUSDT
for i in range(1, 4000):
    u = i * step
    r = full_cycle(u)
    if r[0] - u > best[0]:
        best = (r[0] - u, (u, r))
# refine
bu = best[1][0]
for i in range(-100, 101):
    u = bu + i * (step // 100)
    if u <= 0: continue
    r = full_cycle(u)
    if r[0] - u > best[0]:
        best = (r[0] - u, (u, r))

profit, (u, (xu_out, stc1, fai, seized)) = best
print(f"\nFULL CYCLE OPTIMUM:")
print(f"  spend {u/1e6:,.2f} XUSDT -> {stc1/1e9:,.2f} STC -> {fai/1e9:,.2f} FAI -> seize {seized/1e9:,.2f} STC -> sell -> {xu_out/1e6:,.2f} XUSDT")
print(f"  NET PROFIT = {profit/1e6:,.2f} XUSDT  ({(xu_out/u):.4f}x)")
print(f"  (if starting from STC instead: net +{(seized-stc1)/1e9:,.0f} STC)")

# what if attacker already holds STC and just sells profit?
stc_profit = seized - stc1
xu_from_profit = out(stc_profit, xA, yA)
print(f"\nSTC-holder path: spend {stc1/1e9:,.0f} STC -> seize {seized/1e9:,.0f} -> net {stc_profit/1e9:,.0f} STC -> sell profit -> {xu_from_profit/1e6:,.2f} XUSDT")

json.dump({"reserves_A": resA, "reserves_B": resB, "full_cycle": {"xusdt_in_units": u, "xusdt_out_units": xu_out, "profit_units": profit,
           "stc_spent_units": stc1, "fai_units": fai, "seized_units": seized},
           "stc_holder_net_stc_units": stc_profit, "stc_holder_xusdt_out_units": xu_from_profit},
          open("arb_full_cycle.json", "w"), indent=1)

# recent swap events for validation
print("\n=== recent DEX swap events (explorer) ===")
try:
    req = urllib.request.Request(f"https://doapi.stcscan.io/v2/transaction/address/main/{DEX}/page/1?with_event=true",
                                 headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        d = json.loads(r.read())
    for tx in d.get("contents", [])[:6]:
        for e in tx.get("events", []):
            if "SwapEvent" in e.get("type_tag", ""):
                print("  ts", tx.get("timestamp"), e["type_tag"].split("::")[-1][:80], e["data"][:200])
except Exception as e:
    print("  ERR", e)
