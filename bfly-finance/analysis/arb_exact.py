#!/usr/bin/env python3
"""Enumerate all TokenSwap pairs + compute the exact STC->FAI->liquidate arbitrage."""
import json, urllib.request

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
BF = "0x4ffcc98f43ce74668264a0cf6eebe42b"
r = call("state.list_resource", [DEX])["result"]["resources"]
pairs = []
for k in r:
    if "::TokenSwap::TokenSwapPair<" in k:
        pairs.append(k)
print(f"{len(pairs)} pairs")
for k in pairs:
    v = r[k]["raw"]
    b = bytes.fromhex(v[2:] if v.startswith("0x") else v)
    x = int.from_bytes(b[0:16], "little")
    y = int.from_bytes(b[16:32], "little")
    print(f"  {k.split('TokenSwapPair<')[1][:-1]}: x={x} y={y}")
json.dump({k: r[k]["raw"] for k in pairs}, open("dex_pairs.json", "w"), indent=1)

# exact arbitrage math (Uniswap-v2 style, 0.3% fee)
X = 410813790911242   # STC reserve
Y = 21413902183198    # FAI reserve
PRICE_VALUE = 10000
PENALTY = 10
SEIZE_NUM = 10**8     # collateral_units = cover_units * 1e8 / (price_value*(100-penalty))

def fai_out(dx):
    if dx <= 0: return 0
    return (dx * 997 * Y) // (X * 1000 + dx * 997)

def stc_seized(cover_units):
    return (cover_units * SEIZE_NUM) // (PRICE_VALUE * (100 - PENALTY))

def profit(dx):
    return stc_seized(fai_out(dx)) - dx

# numeric optimization
lo, hi = 1, X // 2
best = None
for i in range(200):
    # ternary-ish scan on profit
    pass
best_dx, best_p = 0, 0
step = X // 10000
for i in range(1, 10000):
    dx = step * i
    p = profit(dx)
    if p > best_p:
        best_p, best_dx = p, dx
# refine
for i in range(1, 1000):
    dx = best_dx - step + (step // 500) * i
    if dx <= 0: continue
    p = profit(dx)
    if p > best_p:
        best_p, best_dx = p, dx
print(f"\nOPTIMAL: spend {best_dx/1e9:,.3f} STC -> receive {fai_out(best_dx)/1e9:,.3f} FAI -> seize {stc_seized(fai_out(best_dx))/1e9:,.3f} STC")
print(f"  profit = {best_p/1e9:,.3f} STC ({(best_p/best_dx):.4f}x)")
print(f"  FAI avg cost = {best_dx/fai_out(best_dx):.4f} STC/FAI")
print(f"  USD at market 0.00011112 = ${best_p/1e9*0.00011112:,.2f}")
print(f"  USD at oracle 0.01       = ${best_p/1e9*0.01:,.2f}")
# full drain of pool FAI
dx_all = X  # would buy nearly all
print(f"\nBuying 90% of FAI: dx={X*9/10/1e9:,.0f} -> fai={fai_out(X*9//10)/1e9:,.1f} -> profit {profit(X*9//10)/1e9:,.1f} STC")
