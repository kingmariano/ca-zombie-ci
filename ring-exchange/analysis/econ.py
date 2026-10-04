#!/usr/bin/env python3
"""Exact extraction economics for Ring pool[1] fwUETH/fwWHYPE (read-only, from pinned snapshot)."""
import json, glob

f = sorted(glob.glob("snapshot_*.json"))[-1]
s = json.load(open(f))
BLK = s["block"]
px = s["prices_simple"]

P1 = s["pairs"]["fwUETH/fwWHYPE"]
r0 = P1["reserve0"] / 1e18   # fwUETH
r1 = P1["reserve1"] / 1e18   # fwWHYPE
pU = px["UETH"]; pW = px["WHYPE"]
wU = s["wrappers"]["fwUETH"]; wW = s["wrappers"]["fwWHYPE"]
collU = wU["underlying_held"] / 1e18
collW = wW["underlying_held"] / 1e18

print(f"block {BLK}")
print(f"pool: {r0:,.3f} fwUETH | {r1:,.3f} fwWHYPE")
print(f"spot:  {r1/r0:.5f} fwWHYPE per fwUETH | market {pU/pW:.5f} WHYPE per UETH -> deviation {(r1/r0)/(pU/pW)-1:+.4%}")
print(f"spot:  {r0/r1:.8f} fwUETH per fwWHYPE | market {pW/pU:.8f} UETH per WHYPE -> deviation {(r0/r1)/(pW/pU)-1:+.4%}")
print(f"wrapper UETH collateral {collU:,.3f} (${collU*pU:,.0f}); wrapper WHYPE collateral {collW:,.3f} (${collW*pW:,.0f})")
print()

def get_amount_out(amount_in, rin, rout):
    ain = amount_in * 997
    return ain * rout / (rin * 1000 + ain)

def roundtrip_buy_first(fw_in, in_name, out_name, in_usd, out_usd):
    """wrap real in -> fw_in, swap to fw_out, unwrap to real out. Return USD pnl."""
    if in_name == "WHYPE":
        amt_out = get_amount_out(fw_in, r1, r0)   # fwWHYPE -> fwUETH
        cost = fw_in * in_usd; got = amt_out * out_usd
    else:
        amt_out = get_amount_out(fw_in, r0, r1)   # fwUETH -> fwWHYPE
        cost = fw_in * in_usd; got = amt_out * out_usd
    return amt_out, got, got - cost, (got/cost - 1)

print("== Buy fwUETH with WHYPE (wrap WHYPE -> swap -> unwrap UETH) ==")
for usd in [10_000, 100_000, 1_000_000, 10_000_000]:
    fw_in = usd / pW
    amt_out, got, pnl, pct = roundtrip_buy_first(fw_in, "WHYPE", "UETH", pW, pU)
    print(f"  spend ${usd:>11,.0f} -> {amt_out:>10,.3f} fwUETH -> ${got:>11,.0f} UETH | PnL ${pnl:>12,.0f} ({pct:+.3%})")

print("== Buy fwWHYPE with UETH (wrap UETH -> swap -> unwrap WHYPE) ==")
for usd in [10_000, 100_000, 1_000_000]:
    fw_in = usd / pU
    amt_out, got, pnl, pct = roundtrip_buy_first(fw_in, "UETH", "WHYPE", pU, pW)
    print(f"  spend ${usd:>11,.0f} -> {amt_out:>10,.3f} fwWHYPE -> ${got:>11,.0f} WHYPE | PnL ${pnl:>12,.0f} ({pct:+.3%})")

# cost to exhaust UETH collateral by buying fwUETH with fwWHYPE
def cost_to_buy(target_fwU, rin=r1, rout=r0):
    # out = 997*x*rin/(1000*rout + 997*x) inverted -> x = 1000*rin*target / (997*(rout - target))
    if target_fwU >= rout: return None
    return rin * 1000 * target_fwU / (997 * (rout - target_fwU))

print()
print("== Cost to exhaust UETH collateral (buy fwUETH with fwWHYPE, then unwrap) ==")
x = cost_to_buy(collU)
print(f"  buy {collU:,.3f} fwUETH out of pool costs {x:,.3f} fwWHYPE (${x*pW:,.0f}) -> unwrap ${collU*pU:,.0f} UETH; PnL ${collU*pU - x*pW:,.0f} ({(collU*pU)/(x*pW)-1:+.3%})")

def cost_to_buy_w(target_fwW, rin=r0, rout=r1):
    # buying fwWHYPE with fwUETH: input reserve r0, output reserve r1
    if target_fwW >= rout: return None
    return rin * 1000 * target_fwW / (997 * (rout - target_fwW))

print("== Cost to exhaust WHYPE collateral (buy fwWHYPE with fwUETH, then unwrap) ==")
xw = cost_to_buy_w(collW)
print(f"  buy {collW:,.3f} fwWHYPE out of pool costs {xw:,.3f} fwUETH (${xw*pU:,.0f}) -> unwrap ${collW*pW:,.0f} WHYPE; PnL ${collW*pW - xw*pU:,.0f} ({(collW*pW)/(xw*pU)-1:+.3%})")

print()
print("== If attacker could mint unbacked fw tokens (P / key-compromise scenario) ==")
print(f"  mint fwWHYPE -> dump for fwUETH -> unwrap: extract up to {collU:,.3f} UETH = ${collU*pU:,.0f}")
print(f"  mint fwUETH -> dump for fwWHYPE -> unwrap: extract up to {collW:,.3f} WHYPE = ${collW*pW:,.0f}")
print(f"  total wrapper collateral (all 5) = ${sum(i.get('collateral_usd') or 0 for i in s['wrappers'].values()):,.0f}")

print()
print("== LP view (pair1) ==")
lp_supply = P1["lp_totalSupply"] / 1e18
lp_price_nominal = P1["tvl_usd_nominal"] / lp_supply
lp_backed = (collU*pU + collW*pW) / lp_supply
print(f"  LP supply {lp_supply:,.3f}; nominal ${lp_price_nominal:,.2f}/LP; collateral-backed ${lp_backed:,.2f}/LP ({lp_backed/lp_price_nominal:.2%})")
