#!/usr/bin/env python3
"""Value accounting for Ra Exchange at a pinned block (read-only)."""
import json

A = "/home/heisenberg/CA/ra-exchange/analysis"
d = json.load(open(f"{A}/live_state2.json"))
prices = json.load(open(f"{A}/prices.json"))

def price(tok):
    p = prices.get(f"fraxtal:{tok.lower()}")
    return p["price"] if p else 0.0

def usd(tok, amt):
    return (amt or 0) * price(tok)

DEC = {}  # decimals cache
import subprocess
RPC = "https://rpc.frax.com"
def dec(tok):
    if tok not in DEC:
        try:
            out = subprocess.check_output(["cast","call",tok,"decimals()(uint8)","--rpc-url",RPC],stderr=subprocess.DEVNULL).decode().strip()
            DEC[tok] = int(out)
        except Exception:
            DEC[tok] = 18
    return DEC[tok]

cl = d["cl_pools"]; pr = d["pairs"]
block = d["block"]

tot_cl_bal = tot_cl_pf = tot_cl_lp = 0.0
pools_with_liq = 0
cl_rows = []
for a, r in cl.items():
    b0 = (r["bal0"] or 0) / 10**dec(r["token0"])
    b1 = (r["bal1"] or 0) / 10**dec(r["token1"])
    p0 = (r["protocolFees0"] or 0) / 10**dec(r["token0"])
    p1 = (r["protocolFees1"] or 0) / 10**dec(r["token1"])
    v_bal = usd(r["token0"], b0) + usd(r["token1"], b1)
    v_pf = usd(r["token0"], p0) + usd(r["token1"], p1)
    v_lp = v_bal - v_pf
    tot_cl_bal += v_bal; tot_cl_pf += v_pf; tot_cl_lp += v_lp
    if (r["liquidity"] or 0) > 0: pools_with_liq += 1
    cl_rows.append((v_bal, v_pf, a, r["token0"], r["token1"], r["fee"], b0, b1, p0, p1, r["liquidity"]))

tot_pr = 0.0
pr_rows = []
for a, r in pr.items():
    r0 = (r["reserve0"] or 0) / 10**dec(r["token0"])
    r1 = (r["reserve1"] or 0) / 10**dec(r["token1"])
    v = usd(r["token0"], r0) + usd(r["token1"], r1)
    tot_pr += v
    pr_rows.append((v, a, r["token0"], r["token1"], r0, r1, r["stable"], r["feeSplit"]))

print(f"block {block}")
print(f"CL pools: {len(cl)}; with liquidity>0: {pools_with_liq}")
print(f"CL total balances USD:   {tot_cl_bal:,.2f}")
print(f"  protocol fees USD (P): {tot_cl_pf:,.2f}")
print(f"  LP-owned USD (H-O):    {tot_cl_lp:,.2f}")
print(f"crAMM pairs reserves USD: {tot_pr:,.2f}")
print(f"TOTAL on-chain USD:      {tot_cl_bal + tot_pr:,.2f}")
print()
print("Top 15 CL pools by balance value:")
for row in sorted(cl_rows, reverse=True)[:15]:
    v_bal, v_pf, a, t0, t1, fee, b0, b1, p0, p1, liq = row
    print(f"  {a} fee={fee} balUSD={v_bal:,.2f} pfUSD={v_pf:,.2f} b0={b0:.6f} b1={b1:.6f} pf0={p0:.6f} pf1={p1:.6f} liq={liq}")
print()
print("Top 12 pairs by reserve value:")
for row in sorted(pr_rows, reverse=True)[:12]:
    v, a, t0, t1, r0, r1, st, fs = row
    print(f"  {a} stable={st} fs={fs} USD={v:,.2f} r0={r0:.6f} r1={r1:.6f} t0={t0} t1={t1}")
json.dump({
    "block": block,
    "cl_total_usd": round(tot_cl_bal,2),
    "cl_protocol_fees_usd": round(tot_cl_pf,2),
    "cl_lp_owned_usd": round(tot_cl_lp,2),
    "pairs_reserves_usd": round(tot_pr,2),
    "total_usd": round(tot_cl_bal+tot_pr,2),
}, open(f"{A}/valuation.json","w"), indent=1)
