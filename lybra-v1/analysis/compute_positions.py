#!/usr/bin/env python3
"""Compute CRs and simulate max liquidation extraction per victim (exact contract math)."""
import json

pos = json.load(open("analysis/positions_raw.json"))
P = 2696560687860000000000  # fetchPrice() at block ~26127072
WAD = 10**18

rows = []
for u, d in pos.items():
    C = d["dep"]; D = d["bor"]; E = d["eusd"]; A = d["allow"]
    if C == 0 and D == 0:
        continue
    if D == 0:
        rows.append(dict(user=u, C=C/WAD, D=0, E=E/WAD, A=A/WAD, CR=None, note="no_debt"))
        continue
    cr = C * P * 100 // D  # 1e18-scaled percent*1e18
    rows.append(dict(user=u, C=C/WAD, D=D/WAD, E=E/WAD, A=A/WAD, CR=cr/1e18))

active = [r for r in rows if r["D"] and r["D"] > 0]
print(f"users with debt: {len(active)} / {len(pos)} total, {len([r for r in rows if r['D']==0])} collateral-only")
uw = [r for r in active if r["CR"] < 150]
print(f"underwater (CR<150%): {len(uw)}")
uw.sort(key=lambda r: r["CR"])
print(f"{'user':44s} {'collateral':>12s} {'debt':>12s} {'CR%':>8s} {'eUSDbal':>10s} {'allow':>8s}")
for r in uw:
    print(f"{r['user']:44s} {r['C']:12.6f} {r['D']:12.2f} {r['CR']:8.2f} {r['E']:10.2f} {r['A']:8.2f}")

# simulate max extraction per victim (multi-round, exact math)
def simulate(C, D):
    """C,D in wei. Returns (total_eth_profit, total_eusd_deployed, rounds)"""
    total_e = 0; total_x = 0; rounds = 0
    while True:
        if D == 0:
            break
        cr = C * P * 100 // D
        if cr >= 150 * WAD:
            break
        e_debt = D * WAD // P
        e_coll = C // 2
        e = min(e_debt, e_coll)
        if e == 0:
            break
        x = e * P // WAD
        if x == 0 or x > D:
            break
        red = e * 11 // 10
        C = C - red
        D = D - x
        total_e += e
        total_x += x
        rounds += 1
    return total_e, total_x, rounds

tot_e = 0; tot_x = 0; results = []
for r in uw:
    C = int(r["C"] * WAD); D = int(r["D"] * WAD)
    e, x, rounds = simulate(C, D)
    tot_e += e; tot_x += x
    results.append(dict(user=r["user"], CR=r["CR"], C=r["C"], D=r["D"],
                        profit_stETH=e/WAD, eusd_deployed=x/WAD, rounds=rounds))
results.sort(key=lambda r: -r["profit_stETH"])
print(f"\n{'user':44s} {'CR%':>8s} {'collateral':>11s} {'debt':>11s} {'profit stETH':>12s} {'eUSD used':>11s} {'rounds':>6s}")
for r in results:
    print(f"{r['user']:44s} {r['CR']:8.2f} {r['C']:11.6f} {r['D']:11.2f} {r['profit_stETH']:12.6f} {r['eusd_deployed']:11.2f} {r['rounds']:6d}")

print(f"\nTOTAL max profit: {tot_e/WAD:.6f} stETH  (eUSD deployed {tot_x/WAD:,.2f})")
print(f"Total eUSD deployed in USD: {tot_x/WAD:.2f} (par)")
print(f"Total stETH profit value @ ${P/WAD:.2f}: ${tot_e/WAD * P/WAD:,.2f}")

# single-shot (one round each) comparison
tot_e1 = 0; tot_x1 = 0
for r in uw:
    C = int(r["C"]*WAD); D = int(r["D"]*WAD)
    e = min(D*WAD//P, C//2)
    if e == 0: continue
    x = e*P//WAD
    if x > D or x == 0: continue
    tot_e1 += e; tot_x1 += x
print(f"\nOne-shot (one round per victim) profit: {tot_e1/WAD:.6f} stETH, eUSD {tot_x1/WAD:,.2f}")

json.dump(dict(price=P, underwater=results, total_profit_stETH=tot_e/WAD,
               total_eusd=tot_x/WAD, one_shot_profit_stETH=tot_e1/WAD,
               one_shot_eusd=tot_x1/WAD, n_underwater=len(uw), n_debt=len(active)),
          open("analysis/extraction_model.json","w"), indent=1)

# eUSD holders with allowance (potential providers/bots)
prov = [r for r in active if r["A"] > 0]
print(f"\naddresses with allowance to Lybra: {len(prov)}")
prov.sort(key=lambda r: -r["A"])
for r in prov[:15]:
    print(f"  {r['user']} allow={r['A']:,.2f} eUSDbal={r['E']:,.2f} debt={r['D']:,.2f}")
tot_allow = sum(r["A"] for r in prov)
print(f"total allowance: {tot_allow:,.2f} eUSD")
