#!/usr/bin/env python3
"""Independent re-implementation of the Swerve/Curve yPool Vyper math (exact integer
arithmetic) to verify fork-observed behaviour of remove_liquidity_imbalance and
quantify the pool's curvature slack (sum(balances) - D).

Read-only analysis. Values from live reads / fork logs.
"""
N = 4
A = 100
FEE = 3_000_000
FEE_DENOMINATOR = 10**10
PRECISION = 10**18
# PRECISION_MUL for [DAI, USDC, USDT, TUSD]
PMUL = [1, 10**12, 10**12, 1]


def get_D(xp):
    S = sum(xp)
    if S == 0:
        return 0
    Dprev = 0
    D = S
    Ann = A * N
    for _ in range(255):
        D_P = D
        for x in xp:
            D_P = D_P * D // (x * N + 1)
        Dprev = D
        D = (Ann * S + D_P * N) * D // ((Ann - 1) * D + (N + 1) * D_P)
        if D > Dprev:
            if D - Dprev <= 1:
                break
        else:
            if Dprev - D <= 1:
                break
    return D


def get_y(i, j, x, xp):
    D = get_D(xp)
    c = D
    S_ = 0
    Ann = A * N
    for k in range(N):
        if k == i:
            _x = x
        elif k != j:
            _x = xp[k]
        else:
            continue
        S_ += _x
        c = c * D // (_x * N)
    c = c * D // (Ann * N)
    b = S_ + D // Ann
    y = D
    for _ in range(255):
        y_prev = y
        y = (y * y + c) // (2 * y + b - D)
        if y > y_prev:
            if y - y_prev <= 1:
                break
        else:
            if y_prev - y <= 1:
                break
    return y


def remove_imbalance(balances, ts, amounts, admin_fee=0):
    """Exact Vyper remove_liquidity_imbalance. balances in coin units."""
    old = list(balances)
    xp = [old[i] * PMUL[i] for i in range(N)]
    D0 = get_D(xp)
    new = list(old)
    for i in range(N):
        new[i] -= amounts[i]
    xp_new = [new[i] * PMUL[i] for i in range(N)]
    D1 = get_D(xp_new)
    _fee = FEE * N // (4 * (N - 1))
    fees = [0] * N
    for i in range(N):
        ideal = D1 * old[i] // D0
        diff = abs(ideal - new[i])
        fees[i] = _fee * diff // FEE_DENOMINATOR
        new[i] -= fees[i]
    xp_new2 = [new[i] * PMUL[i] for i in range(N)]
    D2 = get_D(xp_new2)
    token_amount = (D0 - D2) * ts // D0
    # value the pool's balances keep (admin_fee=0 -> fees stay in balances)
    kept = [old[i] - amounts[i] for i in range(N)]  # self.balances update (fees retained)
    return dict(D0=D0, D1=D1, D2=D2, fees=fees, burned=token_amount, kept=kept)


def val18(b):
    return sum(b[i] * PMUL[i] for i in range(N))


def report(name, balances, ts):
    xp = [balances[i] * PMUL[i] for i in range(N)]
    D = get_D(xp)
    book = val18(balances)
    print(f"-- {name}")
    print(f"   sum(balances)={book/1e18:.6f}  D={D/1e18:.6f}  slack=sum-D={(book-D)/1e18:.6f}")
    print(f"   vp=D*1e18/ts={D*10**18//ts/1e18:.12f}  book/ts={book/ts:.12f} ({(book/ts-1)*100:.6f}%)")
    return D, book


if __name__ == "__main__":
    # 1) live pool state (block ~26,173,731)
    live = [
        75_005_743_491_044_521_345_789,   # DAI
        74_120_265_381,                   # USDC
        81_118_909_394,                   # USDT
        74_604_782_023_302_163_442_796,   # TUSD
    ]
    live_ts = 284_914_257_245_196_369_584_766
    D_live, book_live = report("LIVE pool", live, live_ts)

    # 2) fork-observed state right before the skewed removal (from PoC logs)
    #    ts=312915.786432584623369955, vp=1.069982463580804827
    f = [
        105_005_743_491_044_521_345_789,  # DAI (made rich by attacker)
        74_120_265_380,                   # USDC (-1 from live due to swap rounding)
        81_118_909_393,                   # USDT
        74_604_782_023_302_163_442_796,   # TUSD
    ]
    f_ts = 312_915_786_432_584_623_369_955
    D_f, book_f = report("FORK STATE (pre-remove)", f, f_ts)
    print(f"   expected vp from log: 1069982463580804827 (1.069982463580804827)")
    print(f"   computed vp:          {D_f*10**18//f_ts} ({D_f*10**18/f_ts/1e18:.18f})")
    print(f"   expected D*1e18:      {1069982463580804827*f_ts//10**18}")

    # 3) reproduce the fork-observed remove_liquidity_imbalance
    want = [4_698_263_108_948_895_534_471, 0, 0, 0]
    r = remove_imbalance(f, f_ts, want)
    print("-- remove_imbalance(want 4698.263108948895534471 DAI)")
    print(f"   D0={r['D0']} D1={r['D1']} D2={r['D2']} fees={r['fees']}")
    print(f"   burned LP  = {r['burned']}   (fork log: 4382607473754894887270)")
    fair_vp = r["burned"] * (D_f * 10**18 // f_ts) // 10**18
    fair_book = r["burned"] * book_f // f_ts
    print(f"   value out  = {want[0]} (market 18dec)")
    print(f"   burned*vp  = {fair_vp}  -> single-leg 'gain' = {(want[0]-fair_vp)/1e18:.6f}")
    print(f"   burned*book= {fair_book} -> single-leg 'gain' = {(want[0]-fair_book)/1e18:.6f}")
    # remaining LPs book value change
    rem_ts = f_ts - r["burned"]
    rem_val = val18(r["kept"])
    print(f"   book/share before = {book_f/f_ts:.15f}")
    print(f"   book/share after  = {rem_val/rem_ts:.15f}")
    print(f"   remaining-LP dilution (USD, total) = {(rem_val/rem_ts - book_f/f_ts)*rem_ts/1e18:.6f}")

    # 4) live-state exploit attempt: proportional add then rich-coin (USDT) skew removal
    #    attacker adds 1% proportional, then removes USDT-only until fee+slack captured
    print("-- live-state rich-coin extraction bound (upper bound, fees ignored)")
    # slack available = book - D
    print(f"   live slack = ${(book_live-D_live)/1e18:.6f} -- absolute max capture without own-cost")
