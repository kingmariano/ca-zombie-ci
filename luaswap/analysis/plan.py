#!/usr/bin/env python3
"""Compute the concrete execution plan (exact swap amounts) for the LuaSwap PoC.

Uses pairs_raw_latest.json. Routes:
  A) WTOMO -> USDT direct on pair1 (optimal standalone)
  B) WTOMO -> LUA on pair4, split LUA -> USDT on pair2 and -> ETH on pair18 (joint 2-sink optimum)
  C) WTOMO -> BTC direct on pair19
  D) WTOMO -> tETH on pair891, tETH -> USDT on pair890
  E) WTOMO -> TAI on pair620, TAI -> USDT on pair619
  F) WTOMO -> LEC on pair810, LEC -> USDT on pair809
  G) small: pair3 (ETH direct), pair76->pair68 (USDC->USDT), pair143->pair178 (HY->USDT),
     pair829->pair828 (USDE->USDT), pair1208->pair1207 (MFC->USDT), pair785->pair784 (CBC->USDT),
     pair32->pair226 (SRM->ETH), pair142->pair217 (FTT->ETH), pair73 via USDC, pair22 via ETH
"""
import json, math, sys

FEE = 0.996
VIC = 0.00447556273208646
P_ETH = 2707.786
P_BTC = 85513.65

d = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "pairs_raw_latest.json"))
P = {p["index"]: p for p in d["pairs"]}
T = d["tokens"]

def res(i):
    p = P[i]
    return p["reserve0"], p["reserve1"], p["token0"], p["token1"]

def out_amt(rin, rout, dx):
    return rout * dx * FEE / (rin + dx * FEE)

def in_amt(rin, rout, dy):
    return rin * dy / (FEE * (rout - dy))

def opt_dx(rin, rout, c_per_out):
    """maximize c*out(dx) - dx: dx* = (sqrt(rout*rin*FEE/c) - rin)/FEE  (c = USD per raw in-unit / raw out-unit)"""
    pass

# --- A) pair1 direct ---
r0, r1, t0, t1 = res(1)  # USDT, WTOMO
# sell WTOMO (r1) for USDT (r0): profit = 1.0*out/1e6 - VIC*dx/1e18
# d/dx: rout*FEE*rin/(rin+dx*FEE)^2 * (1/1e6) = VIC/1e18
rin, rout = r1, r0
dxA = (math.sqrt(rout * rin * FEE * (1e18 / 1e6) / VIC) - rin) / FEE
outA = out_amt(rin, rout, dxA)
print(f"A) pair1: sell {dxA/1e18:,.2f} WTOMO -> {outA/1e6:,.6f} USDT  cost ${dxA/1e18*VIC:,.2f} net ${outA/1e6-dxA/1e18*VIC:,.2f}")

# --- B) pair4 -> pair2/pair18 joint ---
W4 = int(P[4]["reserve1"]); L4 = int(P[4]["reserve0"])
L2 = int(P[2]["reserve1"]); U2 = int(P[2]["reserve0"])
E18 = int(P[18]["reserve0"]); L18 = int(P[18]["reserve1"])
# choose l1,l2 maximize U2*out(l2)/1e6 + P_ETH*out(l1)/1e18 - VIC*w(l1+l2)/1e18
def u_out(l): return out_amt(L2, U2, l)
def e_out(l): return out_amt(L18, E18, l)
def w_cost(ltot): return W4 * ltot / (FEE * (L4 - ltot))
best = None
# 2-D coarse + refine
import itertools
for l2 in [x*1e22 for x in range(20, 520, 5)]:
    for l1 in [x*1e22 for x in range(20, 520, 5)]:
        if l1 + l2 >= L4: continue
        val = u_out(l2)/1e6 + P_ETH*e_out(l1)/1e18 - VIC*w_cost(l1+l2)/1e18
        if best is None or val > best[0]: best = (val, l1, l2)
val, l1, l2 = best
# local refine
step = 2e22
for _ in range(60):
    improved = False
    for dl1, dl2 in [(step,0),(-step,0),(0,step),(0,-step),(step,-step),(-step,step)]:
        n1, n2 = l1+dl1, l2+dl2
        if n1 <= 0 or n2 <= 0 or n1+n2 >= L4: continue
        v = u_out(n2)/1e6 + P_ETH*e_out(n1)/1e18 - VIC*w_cost(n1+n2)/1e18
        if v > val: val, l1, l2, improved = v, n1, n2, True
    if not improved: step /= 2
    if step < 1e17: break
dxB = W4*(l1+l2)/(FEE*(L4-(l1+l2)))
print(f"B) pair4: sell {dxB/1e18:,.2f} WTOMO -> { (l1+l2)/1e18:,.2f} LUA (cost ${dxB/1e18*VIC:,.2f})")
print(f"   pair2:  sell {l2/1e18:,.2f} LUA -> {u_out(l2)/1e6:,.6f} USDT")
print(f"   pair18: sell {l1/1e18:,.2f} LUA -> {e_out(l1)/1e18:,.6f} ETH = ${P_ETH*e_out(l1)/1e18:,.2f}")
print(f"   net B = ${u_out(l2)/1e6 + P_ETH*e_out(l1)/1e18 - dxB/1e18*VIC:,.2f}")

# --- C) pair19 BTC direct ---
r0, r1, t0, t1 = res(19)  # BTC, WTOMO
rin, rout = r1, r0
c = VIC / 1e18 * 1e8  # USD per raw BTC
dxC = (math.sqrt(rout * rin * FEE / c) - rin) / FEE
outC = out_amt(rin, rout, dxC)
print(f"C) pair19: sell {dxC/1e18:,.2f} WTOMO -> {outC/1e8:,.8f} BTC (${outC/1e8*P_BTC:,.2f}) cost ${dxC/1e18*VIC:,.2f}")

# --- D) pair891 -> pair890 ---
T8 = int(P[891]["reserve0"]); W8 = int(P[891]["reserve1"])   # tETH, WTOMO
U9 = int(P[890]["reserve0"]); T9 = int(P[890]["reserve1"])   # USDT, tETH
bestD = None
for k in range(1, 10000):
    dx = k * 1e18  # WTOMO
    t = out_amt(W8, T8, dx)
    u = out_amt(T9, U9, t)
    v = u/1e6 - dx/1e18*VIC
    if bestD is None or v > bestD[0]: bestD = (v, dx, t, u)
v, dxD, tD, uD = bestD
print(f"D) pair891: sell {dxD/1e18:,.2f} WTOMO -> {tD/1e18:,.6f} tETH; pair890: -> {uD/1e6:,.6f} USDT cost ${dxD/1e18*VIC:,.2f} net ${v:,.2f}")

# --- E) pair620 -> pair619 ---
TA = int(P[620]["reserve1"]); WT = int(P[620]["reserve0"])
UE = int(P[619]["reserve0"]); TAE = int(P[619]["reserve1"])
bestE = None
for k in range(1, 20000):
    dx = k * 1e17
    t = out_amt(WT, TA, dx)
    u = out_amt(TAE, UE, t)
    v = u/1e6 - dx/1e18*VIC
    if bestE is None or v > bestE[0]: bestE = (v, dx, t, u)
v, dxE, tE, uE = bestE
print(f"E) pair620: sell {dxE/1e18:,.2f} WTOMO -> {tE/1e18:,.6f} TAI; pair619: -> {uE/1e6:,.6f} USDT cost ${dxE/1e18*VIC:,.2f} net ${v:,.2f}")

# --- F) pair810 -> pair809 ---
LE = int(P[810]["reserve0"]); WL = int(P[810]["reserve1"])
UF = int(P[809]["reserve1"]); LEF = int(P[809]["reserve0"])
bestF = None
for k in range(1, 50000):
    dx = k * 1e16
    l = out_amt(WL, LE, dx)
    u = out_amt(LEF, UF, l)
    v = u/1e6 - dx/1e18*VIC
    if bestF is None or v > bestF[0]: bestF = (v, dx, l, u)
v, dxF, lF, uF = bestF
print(f"F) pair810: sell {dxF/1e18:,.2f} WTOMO -> {lF:,.2f} LEC; pair809: -> {uF/1e6:,.6f} USDT cost ${dxF/1e18*VIC:,.2f} net ${v:,.2f}")

# --- G) small routes ---
def route2(src_idx, sink_idx, valuable_dec, price, src_in_is_token0):
    """sell WTOMO into src pool for intermediate, sell intermediate into sink for valuable."""
    ps = P[src_idx]; pk = P[sink_idx]
    # identify intermediate token
    if ps["token0"] == "0xb1f66997a5760428d3a87d68b90bfe0ae64121cc":
        int_tok = ps["token1"]; rin_s = ps["reserve0"]; rout_s = ps["reserve1"]
    else:
        int_tok = ps["token0"]; rin_s = ps["reserve1"]; rout_s = ps["reserve0"]
    if pk["token0"] == int_tok:
        rin_k = pk["reserve0"]; rout_k = pk["reserve1"]
    else:
        rin_k = pk["reserve1"]; rout_k = pk["reserve0"]
    best = None
    for k in range(1, 5000):
        dx = k * 1e17
        m = out_amt(rin_s, rout_s, dx)
        vout = out_amt(rin_k, rout_k, m)
        val = price * vout / (10 ** valuable_dec) - dx / 1e18 * VIC
        if best is None or val > best[0]: best = (val, dx, m, vout)
    return best

for name, si, ki, dec, price in [
    ("pair3 ETH", 3, None, 18, P_ETH),
    ("pair76->68 USDT", 76, 68, 6, 1.0),
    ("pair143->178 USDT", 143, 178, 6, 1.0),
    ("pair829->828 USDT", 829, 828, 6, 1.0),
    ("pair1208->1207 USDT", 1208, 1207, 6, 1.0),
    ("pair785->784 USDT", 785, 784, 6, 1.0),
    ("pair32->226 ETH", 32, 226, 18, P_ETH),
    ("pair142->217 ETH", 142, 217, 18, P_ETH),
]:
    if ki is None:
        # direct: sell WTOMO into pool for valuable
        p = P[si]
        if p["token0"] == "0xb1f66997a5760428d3a87d68b90bfe0ae64121cc":
            rin, rout = p["reserve0"], p["reserve1"]
        else:
            rin, rout = p["reserve1"], p["reserve0"]
        best = None
        for k in range(1, 5000):
            dx = k * 1e15
            vout = out_amt(rin, rout, dx)
            val = price * vout / (10 ** dec) - dx / 1e18 * VIC
            if best is None or val > best[0]: best = (val, dx, vout)
        print(f"G) {name}: sell {best[1]/1e18:,.4f} WTOMO -> {best[2]/10**dec:,.8f} (${price*best[2]/10**dec:,.2f}) net ${best[0]:,.2f}")
    else:
        v, dx, m, vout = route2(si, ki, dec, price, None)
        print(f"G) {name}: sell {dx/1e18:,.4f} WTOMO -> {m/1e18:,.6f} int -> {vout/10**dec:,.6f} (${price*vout/10**dec:,.2f}) net ${v:,.2f}")
