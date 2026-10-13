#!/usr/bin/env python3
"""Exact integer model of Wombat v1-core math (WAD, DSMath rounding).

Implements the functions from CoreV2.sol / Pool.sol (HighCovRatioFeePool)
so we can compare against on-chain quotes and search for profitable paths.
"""
WAD = 10 ** 18
WAD_I = 10 ** 18


def wmul(x, y):
    return (x * y + WAD // 2) // WAD


def wdiv(x, y):
    return (x * WAD + y // 2) // y


def isqrt(y):
    if y < 0:
        raise ValueError("isqrt neg")
    if y == 0:
        return 0
    x = y
    z = (x + 1) // 2
    while z < x:
        x = z
        z = (y // z + z) // 2
    return x


def sqrt_signed(y, scale=WAD):
    """DSMath.sqrt(int256): sqrt of a WAD^2 value y, returns WAD value."""
    return isqrt(y)


# ---------------- CoreV2 math ----------------

def solve_quad(b, c):
    """((sqrt(b^2 + 4*c*WAD) - b) / 2) with signed ints (b,c in WAD)."""
    return (isqrt(b * b + c * 4 * WAD) - b) // 2


def swap_quote_func(Ax, Ay, Lx, Ly, Dx, A):
    """All args WAD ints. Returns uint quote."""
    if Lx == 0 or Ly == 0:
        raise ValueError("CORE_UNDERFLOW")
    D = Ax + Ay - wmul(A, (Lx * Lx) // Ax + (Ly * Ly) // Ay)
    rx_ = wdiv(Ax + Dx, Lx)
    b = (Lx * (rx_ - wdiv(A, rx_))) // Ly - wdiv(D, Ly)
    ry_ = solve_quad(b, A)
    Dy = wmul(Ly, ry_) - Ay
    return abs(Dy)


def withdrawal_amount_in_equil(delta_i, A_i, L_i, A):
    L_i_ = L_i + delta_i
    r_i = wdiv(A_i, L_i)
    rho = wmul(L_i, r_i - wdiv(A, r_i))
    beta = (rho + wmul(delta_i, WAD - A)) // 2
    A_i_ = beta + isqrt(beta * beta + wmul(A, L_i_ * L_i_))
    return A_i - A_i_


def exact_deposit_liquidity_in_equil(D_i, A_i, L_i, A):
    if L_i == 0:
        return D_i
    if A_i + D_i < 0:
        raise ValueError("CORE_UNDERFLOW")
    r_i = wdiv(A_i, L_i)
    k = D_i + A_i
    b = wmul(k, WAD - A) + 2 * wmul(A, L_i)
    c = wmul(k, A_i - (A * L_i) // r_i) - wmul(k, k) + wmul(A, wmul(L_i, L_i))
    l = b * b - 4 * A * c
    return (isqrt(l) - b) // A // 2


def deposit_reward_impl(D, SL, delta_i, A_i, L_i, A):
    if L_i == 0:
        return 0
    if delta_i + SL == 0:
        return L_i - A_i
    r_i_ = targeted_cov_ratio(SL, delta_i, A_i, L_i, D, A)
    return A_i + delta_i - wmul(L_i + delta_i, r_i_)


def targeted_cov_ratio(SL, delta_i, A_i, L_i, D, A):
    r_i = wdiv(A_i, L_i)
    er = equil_cov_ratio(D, SL, A)
    er_ = wdiv(delta_i + wmul(SL, er), delta_i + SL)
    D_ = wmul(SL + delta_i, er_ - wdiv(A, er_))
    b_ = wdiv(D - A_i + (L_i * A) // r_i - D_, L_i + delta_i)
    return solve_quad(b_, A)


def equil_cov_ratio(D, SL, A):
    b = -wdiv(D, SL)
    return solve_quad(b, A)


# ---------------- Pool logic ----------------

def exact_deposit_to_equil(amount, cash, liability, total_supply, amp):
    liability_to_mint = exact_deposit_liquidity_in_equil(amount, cash, liability, amp)
    reward = 0
    if liability_to_mint >= amount:
        reward = liability_to_mint - amount
    else:
        liability_to_mint = amount
    lp = liability_to_mint if liability == 0 else (liability_to_mint * total_supply) // liability
    return lp, liability_to_mint, reward


def withdraw_from(liq, cash, liability, total_supply, amp):
    liability_to_burn = (liability * liq) // total_supply
    if liability_to_burn == 0:
        raise ValueError("ZERO_LIQ")
    amount = withdrawal_amount_in_equil(-liability_to_burn, cash, liability, amp)
    fee = 0
    if liability_to_burn >= amount:
        fee = liability_to_burn - amount
    else:
        amount = liability_to_burn
    return amount, liability_to_burn, fee


def quote_from(from_cash, from_liab, to_cash, to_liab, from_amount, amp, haircut_rate):
    """Returns (actual_to_amount, haircut) — plain Pool._quoteFrom (no high-cov fee)."""
    if from_amount < 0:
        from_amount = wdiv(from_amount, WAD_I - haircut_rate)
    ideal = swap_quote_func(from_cash, to_cash, from_liab, to_liab, from_amount, amp)
    if from_amount > 0 and to_cash < ideal:
        raise ValueError("CASH_NOT_ENOUGH")
    if from_amount > 0:
        haircut = wmul(ideal, haircut_rate)
        return ideal - haircut, haircut
    else:
        return ideal, wmul(-from_amount, haircut_rate)


def high_cov_ratio_fee(init_r, final_r, start_r, end_r):
    if final_r > end_r:
        raise ValueError("COV_LIMIT")
    if final_r <= start_r:
        return 0
    a = 0 if init_r <= start_r else (init_r - start_r) * (init_r - start_r)
    b = (final_r - start_r) * (final_r - start_r)
    return wdiv(((b - a) // (final_r - init_r)) // 2, end_r - start_r)


def quote_from_hcr(from_cash, from_liab, to_cash, to_liab, from_amount, amp, haircut_rate, start_r, end_r):
    actual, haircut = quote_from(from_cash, from_liab, to_cash, to_liab, from_amount, amp, haircut_rate)
    if from_amount >= 0:
        final_from_r = wdiv(from_cash + from_amount, from_liab)
        if final_from_r > start_r:
            hf = wmul(high_cov_ratio_fee(wdiv(from_cash, from_liab), final_from_r, start_r, end_r), actual)
            actual -= hf
            haircut += hf
    return actual, haircut


if __name__ == "__main__":
    # sanity: replicate the source formula for a known case
    print("deposit 1000 stKAIA into pool 0x5cde6338 (source math):")
    cash = 1491848776166182727729427
    liab = 1238634797372335828595315
    ts = 1238482149409192481608582
    amp = 2 * 10 ** 15
    lp, l2m, rew = exact_deposit_to_equil(1000 * 10 ** 18, cash, liab, ts, amp)
    print("  lp:", lp, "liabilityToMint:", l2m, "reward:", rew)
    print("withdraw 1000 LP stKAIA:")
    amount, burn, fee = withdraw_from(1000 * 10 ** 18, cash, liab, ts, amp)
    print("  amount:", amount, "burn:", burn, "fee:", fee)
