#!/usr/bin/env python3
"""Taiga Acala - exact reproduction of Homa exchange rate + StableAsset pool-0 math.
Mirrors deployed pallet code (nutsfinance stable-asset @ aa101e87) and Acala runtime:
 - ExchangeRate (FixedU128) = floor(S * 1e18 / L)
 - ConvertBalanceHoma: converted = floor(rate_raw * raw / 1e18)
 - get_d: U512 stableswap invariant with a=3000, APrecision=100, n=2
"""
import json

S = 19306964240443538          # TotalStakingBonded (DOT 10dp) at block 12188301
L = 100722113901338099         # LDOT total issuance (10dp)
raw_ldot = 10392844659613585   # pallet account raw LDOT
raw_dot = 993810871531292      # pallet account raw DOT
stored_bal = [993810871531292, 2049240653489222]
stored_supply = 3039652087142047  # pool total_supply (10dp)
A = 3000
A_PREC = 100

rate_raw = S * 10**18 // L
print("homa rate_raw:", rate_raw, "=", rate_raw / 1e18)
conv_ldot = rate_raw * raw_ldot // 10**18
print("converted LDOT balance (DOT 10dp):", conv_ldot, "=", conv_ldot / 1e10)
print("implied stored rate:", stored_bal[1] / raw_ldot)
print("rate drop needed to make stored valid:", (stored_bal[1] / raw_ldot) / (rate_raw / 1e18) - 1)

def get_d(balances, a=A, a_prec=A_PREC):
    n = len(balances)
    s = sum(balances)
    if s == 0:
        return 0
    ann = a * n
    d = s
    for _ in range(255):
        p_d = d
        for x in balances:
            p_d = p_d * d // (x * n)
        prev_d = d
        t1 = p_d * n
        t2 = (n + 1) * p_d
        t3 = (ann - a_prec) * d // a_prec + t2
        d = (ann * s // a_prec + t1) * d // t3
        if abs(d - prev_d) <= 1:
            break
    return d

D_stored = get_d(stored_bal)
D_updated = get_d([raw_dot, conv_ldot])
print("D(stored balances):", D_stored, "=", D_stored / 1e10)
print("D(updated balances):", D_updated, "=", D_updated / 1e10)
print("stored total_supply:", stored_supply, "=", stored_supply / 1e10)
print("collect_yield gate: new_d >= old_d ?", D_updated >= stored_supply, f"(deficit {stored_supply - D_updated})")
print("collect_fee gate: new_d >= old_d - 1% ?", D_updated >= stored_supply - stored_supply // 100)

# What rate would be needed for the pool to be interactive (new_d >= old_d)?
lo, hi = 0.0, 2.0
for _ in range(200):
    mid = (lo + hi) / 2
    c = int(mid * raw_ldot)
    if get_d([raw_dot, c]) >= stored_supply:
        hi = mid
    else:
        lo = mid
print("min rate for interactivity:", hi)
print("current rate:", rate_raw / 1e18)
print("gap pct:", (hi / (rate_raw / 1e18) - 1) * 100)

# If interactive at some rate r, what would a swap DOT->LDOT give?
def get_y(balances, token_index, target_d, amplitude=A, a_prec=A_PREC):
    n = len(balances)
    c = target_d
    ssum = 0
    ann = amplitude * n
    for i, b in enumerate(balances):
        if i == token_index:
            continue
        ssum += b
        c = c * target_d // (b * n)
    c = c * target_d * a_prec // (ann * n)
    b_ = ssum + target_d * a_prec // ann
    y = target_d
    for _ in range(255):
        prev = y
        y = (y * y + c) // (2 * y + b_ - target_d)
        if abs(y - prev) <= 1:
            break
    return y

def swap_out(balances, i, j, dx, swap_fee=25_000_000, fee_prec=10_000_000_000):
    b = balances.copy()
    b[i] += dx
    d = get_d(balances)  # d = current total_supply (should equal D(balances) after collect_yield)
    y = get_y(b, j, d)
    dy = (b[j] - y - 1)
    fee = dy * swap_fee // fee_prec
    return dy - fee

# sanity: swap 1000 DOT -> LDOT at the rate that makes pool interactive
for r in [rate_raw / 1e18, hi]:
    bals = [raw_dot, int(r * raw_ldot)]
    d = get_d(bals)
    dy = swap_out(bals, 0, 1, 1000 * 10**10)
    print(f"at rate {r:.6f}: D={d/1e10:.2f} swap 1000 DOT -> {dy/1e10:.4f} LDOT-eq (raw LDOT {(int(dy/ (r)) if r>0 else 0)/1e10:.4f})")

# What if rate recovers to 1.0 (if staking were replenished)?
bals = [raw_dot, raw_ldot]
print("D at rate 1.0:", get_d(bals) / 1e10, "vs supply", stored_supply / 1e10)

# Print all raw numbers for report
print(json.dumps({
    "rate_raw": str(rate_raw), "rate": rate_raw / 1e18,
    "conv_ldot": str(conv_ldot), "D_stored": str(D_stored), "D_updated": str(D_updated),
    "stored_supply": str(stored_supply),
    "interactive_now": D_updated >= stored_supply,
    "min_rate_interactive": hi,
}, indent=1))
