#!/usr/bin/env python3
"""Reconcile dYdX distribution module account = community pool + sum(outstanding rewards).
All amounts are DecCoins in BASE units (verified: validator adydx reward as tokens would exceed supply)."""
import json, glob, os
from decimal import Decimal, getcontext
getcontext().prec = 60

RAW = "/home/heisenberg/CA/dydx-chain/analysis/raw"

def dec(x): return Decimal(str(x))

# --- sum outstanding rewards over 21 validators ---
tot = {}
for f in sorted(glob.glob(os.path.join(RAW, "rewards", "rewards_*.json"))):
    j = json.load(open(f))
    for r in j.get("rewards", {}).get("rewards", []):
        tot[r["denom"]] = tot.get(r["denom"], Decimal(0)) + dec(r["amount"])

print("== sum of 21 validator outstanding rewards (base units) ==")
for d, a in tot.items():
    print(f"  {d}: {a}")

# --- distribution module account balances (recon fetch) ---
bal = {b["denom"]: dec(b["amount"]) for b in json.load(open(f"{RAW}/balances_dist_recon.json"))["balances"]}
print("\n== distribution module account balances (base units) ==")
for d, a in bal.items():
    print(f"  {d}: {a}")

# --- community pool query (recon fetch) ---
pool = {p["denom"]: dec(p["amount"]) for p in json.load(open(f"{RAW}/community_pool_recon.json"))["pool"]}
print("\n== community pool query display (base units per DecCoin convention) ==")
for d, a in pool.items():
    print(f"  {d}: {a}")

print("\n== reconciliation: account - rewards =?= pool ==")
for d in set(list(bal) + list(pool) + list(tot)):
    implied = bal.get(d, Decimal(0)) - tot.get(d, Decimal(0))
    print(f"  {d}:")
    print(f"    implied pool (acct - rewards) = {implied}")
    print(f"    query pool                    = {pool.get(d, 'n/a')}")
    if d in pool:
        print(f"    diff (query - implied)        = {pool[d] - implied}")

# --- human-readable conversions ---
print("\n== human units ==")
DYDX = Decimal(10) ** 18
USDC = Decimal(10) ** 6
for d, a in bal.items():
    if d == "adydx":
        print(f"  distribution adydx = {a / DYDX} DYDX")
    elif d.startswith("ibc/8E27"):
        print(f"  distribution uusdc = {a / USDC} USDC")
    else:
        print(f"  distribution {d[:16]}... = {a} base units (decimals TBD)")
for d, a in tot.items():
    if d == "adydx":
        print(f"  rewards adydx = {a / DYDX} DYDX")
    elif d.startswith("ibc/8E27"):
        print(f"  rewards uusdc = {a / USDC} USDC")
for d, a in pool.items():
    if d == "adydx":
        print(f"  pool adydx = {a} base units = {a / DYDX} DYDX")
    elif d.startswith("ibc/8E27"):
        print(f"  pool uusdc = {a} base units = {a / USDC} USDC")
    elif d.startswith("ibc/1578"):
        print(f"  pool stadydx = {a} base units = {a} * 10^-18 tokens if 18dp")
