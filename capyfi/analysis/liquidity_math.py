#!/usr/bin/env python3
"""Depth/slippage math for CapyFi-relevant Uniswap v4 pools (CP approximation within active range)."""
import json, math
from web3 import Web3

eth = Web3(Web3.HTTPProvider("https://ethereum-rpc.publicnode.com", request_kwargs={"timeout": 60}))
STATE_VIEW = Web3.to_checksum_address("0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227")
ABI = [
    {"name":"getSlot0","outputs":[{"type":"uint160"},{"type":"int24"},{"type":"uint24"},{"type":"uint24"}],
     "inputs":[{"name":"poolId","type":"bytes32"}],"stateMutability":"view","type":"function"},
    {"name":"getLiquidity","outputs":[{"type":"uint128"}],"inputs":[{"name":"poolId","type":"bytes32"}],"stateMutability":"view","type":"function"},
    {"name":"getTickBitmap","outputs":[{"type":"uint256"}],"inputs":[{"name":"poolId","type":"bytes32"},{"name":"wordPosition","type":"int16"}],"stateMutability":"view","type":"function"},
]
sv = eth.eth.contract(address=STATE_VIEW, abi=ABI)

POOLS = {
  "LAC/USDC_1pct": dict(pid="0xa8f7d3148be7c6e66462f7d5da7843c94d974e0697e1768fb9c8b695f986a45b",
      c0=("LAC",18), c1=("USDC",6), fee=10000, px0=0.01015818133769269),
  "RPC/USDC_0.3pct": dict(pid="0xd8442c1d563ba9b7dc1bba16430f6f999c0f8dd26914ca757d43ce88d416ebc7",
      c0=("USDC",6), c1=("RPC",18), fee=3000, px0=None),  # px0 = c1 per c0 = RPC per USDC
}

def fmt(x, d=2):
    return f"{x:,.{d}f}"

out = {}
for name, p in POOLS.items():
    pid_b = bytes.fromhex(p["pid"][2:])
    s0 = sv.functions.getSlot0(pid_b).call()
    L = sv.functions.getLiquidity(pid_b).call()
    sqrtP = s0[0] / 2**96
    tick = s0[1]
    x = L / sqrtP / 10**p["c0"][1]   # reserve of c0 in human units
    y = L * sqrtP / 10**p["c1"][1]   # reserve of c1 in human units
    # price: c1 per c0 (human)
    p_c1_per_c0 = (sqrtP**2) * 10**(p["c0"][1]-p["c1"][1])
    rec = {"pool_id": p["pid"], "tick": tick, "lpFee_bps": s0[3]/100, "liquidity_L": str(L),
           "reserve_c0": f'{p["c0"][0]} {fmt(x,4)}', "reserve_c1": f'{p["c1"][0]} {fmt(y,4)}',
           "price_c1_per_c0": p_c1_per_c0,
           "tvl_usd_approx": None}
    # nearest initialized ticks (tickSpacing 200 for 1%, 60 for 0.3%)
    spacing = 200 if p["fee"] == 10000 else 60
    cur_word = tick >> 8
    init_ticks = []
    for w in range(cur_word-3, cur_word+4):
        try:
            bm = sv.functions.getTickBitmap(pid_b, w).call()
            for bit in range(256):
                if (bm >> bit) & 1:
                    init_ticks.append((w << 8) + bit)
        except Exception as e:
            init_ticks.append(("err", str(e)[:40]))
    init_ticks = [t for t in init_ticks if isinstance(t, int)]
    below = [t for t in init_ticks if t <= tick]
    above = [t for t in init_ticks if t > tick]
    rec["nearest_init_tick_below"] = max(below) if below else None
    rec["nearest_init_tick_above"] = min(above) if above else None
    out[name] = rec

# ---- economics ----
# LAC/USDC pool: X LAC, Y USDC; price P = Y/X = 0.01015818
X = 419363.7408927623; Y = 4259.972926441852; P = Y / X
rpc = out["RPC/USDC_0.3pct"]
Xr = rpc["reserve_c1"].split()[1].replace(",", ""); Xr = 923771.3524261008  # RPC
Yr = 9810.751029267742  # USDC
Pr = Yr / Xr  # USDC per RPC

def sell_out(x0, y0, n):
    return y0 * n / (x0 + n)
def buy_cost(x0, y0, n):
    return y0 * n / (x0 - n)
def pump_cost(y0, factor):
    return y0 * (math.sqrt(factor) - 1)

econ = {
 "LAC_USDC_pool": {
   "price_usd_per_LAC": P,
   "pool_tvl_usd": (X*P + Y),
   "sell": {f"LAC {int(n)}": {"nominal_usd": n*P, "usdc_out": sell_out(X, Y, n), "loss_pct": (1-sell_out(X,Y,n)/(n*P))*100}
            for n in (1000, 10000, 100000, 400000, 1000000, 9840000)},
   "buy": {f"LAC {int(n)}": {"nominal_usd": n*P, "usdc_cost": buy_cost(X, Y, n), "premium_pct": (buy_cost(X,Y,n)/(n*P)-1)*100}
           for n in (1000, 10000, 100000, 300000, 377000)},
   "pump_cost_usd": {f"x{f}": pump_cost(Y, f) for f in (1.1, 1.25, 1.5, 2, 5, 10, 100)},
   "max_LAC_buyable": X, "max_usdc_sellable_asymptotic": Y,
 },
 "RPC_USDC_pool": {
   "price_usd_per_RPC": Pr,
   "pool_tvl_usd": (Xr*Pr + Yr),
   "sell": {f"RPC {int(n)}": {"nominal_usd": n*Pr, "usdc_out": sell_out(Xr, Yr, n), "loss_pct": (1-sell_out(Xr,Yr,n)/(n*Pr))*100}
            for n in (10000, 100000, 923000, 1000000, 9230000)},
   "buy": {f"RPC {int(n)}": {"nominal_usd": n*Pr, "usdc_cost": buy_cost(Xr, Yr, n), "premium_pct": (buy_cost(Xr,Yr,n)/(n*Pr)-1)*100}
           for n in (10000, 100000, 800000)},
   "pump_cost_usd": {f"x{f}": pump_cost(Yr, f) for f in (1.1, 1.25, 1.5, 2, 5, 10, 100)},
   "max_RPC_buyable": Xr, "max_usdc_sellable_asymptotic": Yr,
 },
 "oracle_vs_market": {
   "LAC_oracle_usd": 0.010015,
   "LAC_market_usd": P,
   "LAC_oracle_vs_market_pct": (0.010015/P - 1)*100,
   "RPC_oracle_usd": 0.01059766,
   "RPC_market_usd": Pr,
   "RPC_oracle_vs_market_pct": (0.01059766/Pr - 1)*100,
   "LAC_lachain_oracle_usd": 0.009995,
   "LAC_lachain_oracle_vs_eth_market_pct": (0.009995/P - 1)*100,
 }
}
print(json.dumps({"pools": out, "econ": econ}, indent=1, default=str))
