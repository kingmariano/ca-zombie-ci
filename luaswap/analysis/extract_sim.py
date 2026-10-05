#!/usr/bin/env python3
"""LuaSwap (Viction) extraction simulation.

- Builds the pool graph from pairs_raw.json (or a given file)
- BFS-reachability from WTOMO (mintable 1:1 with VIC via deposit())
- Identifies pools holding valuable bridged tokens
- Greedy extraction simulation (UniswapV2 constant product, 0.3% fee)
  * direct routes: sell WTOMO -> valuable token
  * 2-hop routes: sell WTOMO -> intermediate Y, sell Y -> valuable token
- Reports gross valuable-token value reachable and simulated net extraction.

Read-only; no transactions.
"""
import json, sys, math
from collections import deque

WTOMO = "0xb1f66997a5760428d3a87d68b90bfe0ae64121cc"

# Real bridged assets on Viction (old TomoBridge) with USD prices.
# Only canonical addresses are listed. Prices from DefiLlama/CoinGecko 2026-10-05.
VALUABLE = {
    "0x381b31409e4d220919b2cff012ed94d70135a59e": ("USDT", 6, 1.0),
    "0xcca4e6302510d555b654b3eab9c0fcb223bcfdf0": ("USDC", 6, 1.0),
    "0x2eaa73bd0db20c64f53febea7b5f5e5bccc7fb8b": ("ETH", 18, 2707.786),
    "0xae44807d8a9ce4b30146437474ed6faaafa1b809": ("BTC", 8, 85513.65),
    "0xccdc431e7c13798177f2f8eb6b4136df894221d6": ("WBTC", 8, 85513.65),
    "0x771b1f2dd788accc76433db5787f9d3afece0103": ("DAI", 18, 1.0),
}
# extra candidates to inspect (identity to verify)
CANDIDATES = {
    "0xa1ff8559646a79e47ecdfaca60272f3081998569": ("tETH", 18, None),
    "0xdc8a7c567a643b17b8692150653e88375a6bea1a": ("TUSD", 18, None),
    "0x503b2ddc059b81788fd1239561596614b27faade": ("WBTC(2)", 8, None),
    "0xa91895630f2dafdc4fc5c3e32846108068c67004": ("WBTC(3)", 8, None),
    "0x57feaf956da144c3a46366b4b0e0572264bee6c3": ("WBTC(4)", 8, None),
    "0x126d931d123cb0276ee91f9be152aacfbbeb0689": ("WETH", 18, None),
    "0x9befa435e06249d0f987dc546a43b7ad8d2ecbec": ("BUSD", 18, None),
    "0x3903d7416c075379e767291863c180487f897114": ("PAX", 18, None),
    "0x4ceed28f5cc2bd5a13e0a688eda209970da06f43": ("GUSD", 2, None),
}

VIC_USD = 0.00447556273208646
FEE = 0.997

def load(path):
    d = json.load(open(path))
    pools = []
    for p in d["pairs"]:
        r0, r1 = p.get("reserve0"), p.get("reserve1")
        if r0 is None or r1 is None:
            continue
        pools.append({"idx": p["index"], "pair": p["pair"], "t0": p["token0"], "t1": p["token1"],
                      "r0": r0, "r1": r1, "sym0": d["tokens"].get(p["token0"], {}).get("symbol"),
                      "sym1": d["tokens"].get(p["token1"], {}).get("symbol"),
                      "dec0": d["tokens"].get(p["token0"], {}).get("decimals"),
                      "dec1": d["tokens"].get(p["token1"], {}).get("decimals")})
    return d, pools

def amount_out(rin, rout, dx):
    if dx <= 0 or rin <= 0 or rout <= 0:
        return 0.0
    return rout * (dx * FEE) / (rin + dx * FEE)

def amount_in(rin, rout, dy):
    """input needed to get dy out"""
    if dy <= 0 or rin <= 0 or rout <= 0 or dy >= rout:
        return float("inf")
    return rin * dy / (FEE * (rout - dy))

def build_adj(pools):
    adj = {}
    for p in pools:
        if p["r0"] > 0 and p["r1"] > 0:
            adj.setdefault(p["t0"], []).append((p["t1"], p))
            adj.setdefault(p["t1"], []).append((p["t0"], p))
    return adj

def bfs_reach(adj, src):
    seen = {src}
    q = deque([src])
    while q:
        t = q.popleft()
        for nxt, p in adj.get(t, []):
            if nxt not in seen:
                seen.add(nxt)
                q.append(nxt)
    return seen

def main(path="pairs_raw.json"):
    d, pools = load(path)
    adj = build_adj(pools)
    reach = bfs_reach(adj, WTOMO)
    print(f"# block {d['block']} pairs {d['pair_count']} nonzero-liquidity pools {sum(1 for p in pools if p['r0']>0 and p['r1']>0)}")
    print(f"# tokens reachable from WTOMO: {len(reach)}")
    # pools by token
    print("\n## Pools holding canonical valuable tokens (Viction real bridged assets)")
    grand = 0.0
    for tok, (sym, dec, price) in VALUABLE.items():
        tot = 0.0
        rows = []
        for p in pools:
            if p["r0"] <= 0 or p["r1"] <= 0:
                continue
            if p["t0"] == tok:
                amt = p["r0"] / 10**dec; other, osym = p["t1"], p["sym1"]; oraw = p["r1"]
            elif p["t1"] == tok:
                amt = p["r1"] / 10**dec; other, osym = p["t0"], p["sym0"]; oraw = p["r0"]
            else:
                continue
            if amt == 0:
                continue
            tot += amt
            direct = any(q["t0"] in (WTOMO, tok) and q["t1"] in (WTOMO, tok) and q["t0"] != q["t1"] and q is not p for q in pools)
            # is the partner reachable from WTOMO?
            ok = other in reach
            rows.append((p["idx"], p["pair"], amt, other, osym, ok, oraw))
        print(f"\n### {sym} {tok} price=${price} total_in_pools={tot:.6f} USD={tot*price:.2f}")
        for idx, pair, amt, other, osym, ok, oraw in sorted(rows, key=lambda r: -r[2]):
            print(f"  pool {idx:4d} {pair} amount={amt:.6f} partner={osym} {other} reachable={ok} partner_reserve={oraw}")
        grand += tot * price
    print(f"\n## Gross value of canonical assets across all pools (reachable or not): ${grand:,.2f}")

    # how much of each valuable token sits in pools whose partner is reachable
    print("\n## Reachable-pool value (partner token reachable from WTOMO; circular excluded)")
    for tok, (sym, dec, price) in VALUABLE.items():
        tot = 0.0
        for p in pools:
            if p["r0"] <= 0 or p["r1"] <= 0:
                continue
            if p["t0"] == tok:
                amt = p["r0"] / 10**dec; other = p["t1"]
            elif p["t1"] == tok:
                amt = p["r1"] / 10**dec; other = p["t0"]
            else:
                continue
            if other in reach:
                tot += amt
        print(f"  {sym}: {tot:.6f} = ${tot*price:,.2f}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "pairs_raw.json")
