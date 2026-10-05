#!/usr/bin/env python3
"""LuaSwap (Viction) marginal-step greedy extraction simulator (corrected).

- Routes: WTOMO -> ... -> valuable token, built from shortest acquisition path.
- Greedy: each step executes a small fraction (default 0.5%) of the chosen
  route's first-pool WTOMO reserve on the route with the highest *marginal*
  USD profit (price_out * prod(rout*FEE/rin) / 10^dec_out - VIC_USD/1e18).
  This balances shared source pools (LUA, TAI, HY, ...) automatically.
- Reserves update after every step; stops when no route has positive marginal.
"""
import json, sys, math
from collections import deque, defaultdict

WTOMO = "0xb1f66997a5760428d3a87d68b90bfe0ae64121cc"
VIC_USD = 0.00447556273208646
FEE = 0.996

CANON = {
    "0x381b31409e4d220919b2cff012ed94d70135a59e": ("USDT", 6, 1.0),
    "0xcca4e6302510d555b654b3eab9c0fcb223bcfdf0": ("USDC", 6, 1.0),
    "0x2eaa73bd0db20c64f53febea7b5f5e5bccc7fb8b": ("ETH", 18, 2707.786),
    "0xae44807d8a9ce4b30146437474ed6faaafa1b809": ("BTC", 8, 85513.65),
    "0xccdc431e7c13798177f2f8eb6b4136df894221d6": ("WBTC", 8, 85513.65),
    "0x771b1f2dd788accc76433db5787f9d3afece0103": ("DAI", 18, 1.0),
}
EXTRA = {
    "0x503b2ddc059b81788fd1239561596614b27faade": ("WBTC2", 8, 85513.65),
    "0xa91895630f2dafdc4fc5c3e32846108068c67004": ("WBTC3", 8, 85513.65),
    "0xa1ff8559646a79e47ecdfaca60272f3081998569": ("tETH", 18, 2707.786),
}

class Pool:
    __slots__ = ("idx", "pair", "t0", "t1", "r0", "r1")
    def __init__(self, idx, pair, t0, t1, r0, r1):
        self.idx, self.pair, self.t0, self.t1, self.r0, self.r1 = idx, pair, t0, t1, r0, r1
    def rin(self, tin):
        return self.r0 if tin == self.t0 else self.r1
    def rout(self, tin):
        return self.r1 if tin == self.t0 else self.r0
    def out(self, tin, dx):
        if dx <= 0: return 0.0
        rin, rout = self.rin(tin), self.rout(tin)
        if rin <= 0 or rout <= 0: return 0.0
        return rout * dx * FEE / (rin + dx * FEE)
    def apply(self, tin, dx, dy):
        if tin == self.t0:
            self.r0 += dx; self.r1 -= dy
        else:
            self.r1 += dx; self.r0 -= dy

def load(path):
    d = json.load(open(path))
    pools = []
    for p in d["pairs"]:
        r0, r1 = p.get("reserve0"), p.get("reserve1")
        if r0 is None or r1 is None or r0 <= 0 or r1 <= 0:
            continue
        pools.append(Pool(p["index"], p["pair"], p["token0"], p["token1"], r0, r1))
    return d, pools

def build_adj(pools):
    adj = {}
    for p in pools:
        adj.setdefault(p.t0, []).append((p.t1, p))
        adj.setdefault(p.t1, []).append((p.t0, p))
    return adj

def bfs_path(adj, src, dst, exclude_pool, max_hops=5):
    if src == dst: return []
    q = deque([(src, [])]); seen = {src}
    while q:
        tok, path = q.popleft()
        if len(path) >= max_hops: continue
        for nxt, pool in adj.get(tok, []):
            if pool is exclude_pool or nxt in seen: continue
            npath = path + [(pool, tok, nxt)]
            if nxt == dst: return npath
            seen.add(nxt); q.append((nxt, npath))
    return None

def exec_route(route, dx):
    cur = dx; det = []
    for pool, tin, tout in route:
        dy = pool.out(tin, cur)
        if dy <= 0: return 0.0, det
        det.append((pool, tin, cur, dy)); cur = dy
    return cur, det

def marginal(route, price, dec):
    """USD per raw WTOMO at dx->0."""
    prod = 1.0
    for pool, tin, tout in route:
        rin, rout = pool.rin(tin), pool.rout(tin)
        if rin <= 0 or rout <= 0: return -1
        prod *= rout * FEE / rin
    return price * prod / (10 ** dec) - VIC_USD / 1e18

def main(path, step_frac=0.005, max_iters=300000, extra=False):
    d, pools = load(path)
    adj = build_adj(pools)
    val = dict(CANON)
    if extra: val.update(EXTRA)
    routes = []
    seen = set()
    for P in pools:
        for tok in (P.t0, P.t1):
            if tok not in val: continue
            sym, dec, price = val[tok]
            Y = P.t1 if tok == P.t0 else P.t0
            if Y == WTOMO:
                route = [(P, WTOMO, tok)]
            else:
                acq = bfs_path(adj, WTOMO, Y, exclude_pool=P, max_hops=5)
                if not acq: continue
                route = acq + [(P, Y, tok)]
            key = tuple((pool.idx, tin, tout) for pool, tin, tout in route)
            if key in seen: continue
            seen.add(key)
            routes.append({"route": route, "sym": sym, "dec": dec, "price": price})
    print(f"# block {d['block']} pools {len(pools)} routes {len(routes)} step={step_frac}")
    extracted = defaultdict(float)   # sym -> normalized amount
    route_value = defaultdict(float) # key -> USD
    vic_spent = 0.0
    it = 0
    while it < max_iters:
        best = None
        for r in routes:
            m = marginal(r["route"], r["price"], r["dec"])
            if m <= 0: continue
            if best is None or m > best[0]:
                p0, tin0, _ = r["route"][0]
                dx = step_frac * p0.rin(tin0)
                best = (m, r, dx)
        if best is None: break
        m, r, dx = best
        dy, det = exec_route(r["route"], dx)
        if dy <= 0:
            # cannot execute; mark route dead by faking huge negative? just skip by removing
            routes.remove(r); continue
        for pool, tin, dxx, dyy in det:
            pool.apply(tin, dxx, dyy)
        extracted[r["sym"]] += dy / (10 ** r["dec"])
        route_value[tuple((pool.idx, tin, tout) for pool, tin, tout in r["route"])] += dy / (10 ** r["dec"]) * r["price"]
        vic_spent += dx / 1e18
        it += 1
        if it % 2000 == 0:
            tot = sum(extracted[s] * [v[2] for v in val.values() if v[0] == s][0] for s in extracted)
            print(f"  it {it}: VIC spent {vic_spent:.1f} (${vic_spent*VIC_USD:.2f}) extracted ${tot:.2f}")
    print(f"\n## Result after {it} steps")
    total = 0.0
    for sym, amt in sorted(extracted.items(), key=lambda kv: -kv[1] * [v[2] for v in val.values() if v[0] == kv[0]][0]):
        price = [v[2] for v in val.values() if v[0] == sym][0]
        usd = amt * price; total += usd
        print(f"  {sym:6s}: {amt:.8f} = ${usd:,.2f}")
    print(f"  VIC spent: {vic_spent:,.1f} WTOMO = ${vic_spent*VIC_USD:,.2f}")
    print(f"  GROSS ${total:,.2f}  NET ${total - vic_spent*VIC_USD:,.2f}")
    print("\n## Routes by value (top 25)")
    for key, v in sorted(route_value.items(), key=lambda kv: -kv[1])[:25]:
        syms = []
        for idx, tin, tout in key:
            pool = next(p for p in pools if p.idx == idx)
            syms.append(f"{pool.pair[:8]}")
        print(f"  ${v:9.2f}  {' -> '.join(syms)}")
    import os
    if os.environ.get("DEBUG"):
        print("\n## Final state of key pools")
        for idx in [1, 2, 4, 18, 19, 890, 891, 620, 619, 810, 809, 3, 76, 68, 780, 751]:
            pool = next((p for p in pools if p.idx == idx), None)
            if pool:
                print(f"  pool {idx} {pool.pair}: t0={pool.t0[:10]} r0={pool.r0/1e18 if pool.r0>1e15 else pool.r0} t1={pool.t1[:10]} r1={pool.r1/1e18 if pool.r1>1e15 else pool.r1}")
        print("\n## Active routes at end (marginal > 0)")
        n = 0
        for r in routes:
            m = marginal(r["route"], r["price"], r["dec"])
            if m > 0:
                n += 1
                print(f"  m={m:.3e} {r['sym']} route={' -> '.join(p.pair[:8] for p,_,_ in r['route'])}")
        print("  active routes:", n)
    return extracted, vic_spent

if __name__ == "__main__":
    p = sys.argv[1] if len(sys.argv) > 1 else "pairs_raw.json"
    extra = "--extra" in sys.argv
    main(p, extra=extra)
