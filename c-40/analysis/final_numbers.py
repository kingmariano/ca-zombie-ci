#!/usr/bin/env python3
"""Compute final USD numbers for C-40 from captured raw balances + DefiLlama prices."""
import json

prices = json.load(open("prices.json"))
NSTR_PX = 0.0058  # news range $0.0055-$0.0059 (2026-09-18); pool-implied $0.00533; feed-implied $0.00595
prices["NSTR"] = NSTR_PX
prices["nstSTRK"] = prices["STRK"]  # 1:1 backed, deprecated vault

# raw balances: Nostra token + Collateral token + IRM + deferred adapter (+ owner? no, that's treasury)
CASH = {
 "ETH": 1683321646556072236 + 50021788463640038791 + 87139188021097751,
 "USDC": 1078483284 + 234958815 + 658709280,
 "USDT": 262793372 + 256515482 + 219093847,
 "DAIv0": 174554616930246702282 + 15906491879061744822 + 11874453993292820636222 + 5407603072137857214,
 "DAI": 51470090677360088829,
 "WBTC": 89100 + 16651 + 59506,
 "wstETH": 0 + 0 + 221034047039212507,
 "STRK": 10841359140535187271648 + 10059354596276109258466 + 3100559968234267360583,
 "nstSTRK": 1136948337194682886505 + 1488260773602873590835 + 992108059159437224352553,
 "LORDS": 0 + 15251676549991221231 + 1007566078951101875509991,
 "UNO": 115527485860720 + 1104618056411254216 + 9600767743788842049658,
 "NSTR": 1231312136766703841112 + 399999998386060589999940 + 5883929986019609621438147,
 "EKUBO": 492412944487 + 49085263689707432030 + 2031528584892455746287,
}
DEC = {"WBTC":8,"USDC":6,"USDT":6,"ETH":18,"DAIv0":18,"DAI":18,"wstETH":18,"STRK":18,"nstSTRK":18,
       "LORDS":18,"UNO":18,"NSTR":18,"EKUBO":18}
cash_usd = {}
for a,raw in CASH.items():
    amt = raw / 10**DEC[a]
    cash_usd[a] = amt * prices[a]
total_cash = sum(cash_usd.values())

# Outstanding debt (debt token totalSupply)
DEBT = {
 "ETH": 1088674504458239633655, "USDC": 372748374450, "USDT": 312316182689,
 "DAIv0": 2121967532840240669558, "DAI": 38965208302307163306493, "WBTC": 316828807,
 "wstETH": 2563096993371485621, "STRK": 31184270735320883847786207,
 "nstSTRK": 61416899401048048133007, "LORDS": 962662961205132348599,
 "UNO": 8622669629362607422255, "NSTR": 705563504495808756915590, "EKUBO": 0,
}
debt_usd = {a: DEBT[a]/10**DEC[a]*prices[a] for a in DEBT}
total_debt = sum(debt_usd.values())

# Pools reserves (token_0, token_1) with decimals
POOL = {
 "STRK/ETH": (292719396514361496061225, 4748478452722484585, "STRK", "ETH"),
 "STRK/USDC": (154455210029735489790578, 6714120105, "STRK", "USDC"),
 "USDC/USDT": (15910405729, 23538359858, "USDC", "USDT"),
 "ETH/USDC": (4900209121187724730, 13133665918, "ETH", "USDC"),
 "ETH/USDT": (896666248150440370, 2398729902, "ETH", "USDT"),
 "LORDS/ETH": (871445435030683125614650, 816424524887093137, "LORDS", "ETH"),
 "WBTC/ETH": (1373416, 433156506418580686, "WBTC", "ETH"),
 "nstSTRK/STRK": (19595573270011187161219, 90150553915853661063020, "nstSTRK", "STRK"),
 "ETH/UNO": (264412574254284390, 657491510886747683033, "ETH", "UNO"),
 "STRK/UNO": (17897565868328171848652, 720832596812759913773, "STRK", "UNO"),
 "STRK/ETH-D": (65389408790466292957930, 1199738260841717034, "STRK", "ETH"),
 "STRK/USDC-D": (128064548055454156299286, 7435905841, "STRK", "USDC"),
 "ETH/USDC-D": (6643246201986153817, 14291657648, "ETH", "USDC"),
 "WBTC/ETH-D": (19866381, 5876115417392214067, "WBTC", "ETH"),
 "wstETH/ETH": (77891805358235040, 377520444482333448, "wstETH", "ETH"),
 "USDC/DAI": (59484344, 80003027714666184552, "USDC", "DAI"),
 "NSTR/USDC": (9812341403356397093235032, 52293678845, "NSTR", "USDC"),
}
pool_usd = {}
for name,(r0,r1,t0,t1) in POOL.items():
    v = r0/10**DEC[t0]*prices[t0] + r1/10**DEC[t1]*prices[t1]
    pool_usd[name] = v
total_pools = sum(pool_usd.values())

# nstSTRK vault
nst_vault_strk = 1247493.523166143
nst_vault_usd = nst_vault_strk * prices["STRK"]

# Alpha market cash
alpha = {
 "ETH": 10412097929320647961/1e18*prices["ETH"],
 "USDC": 2721871614/1e6*prices["USDC"],
 "USDT": 586359370/1e6*prices["USDT"],
 "DAI": 378293705153532873407/1e18*prices["DAI"],
 "WBTC": 107257/1e8*prices["WBTC"],
}
alpha_total = sum(alpha.values())

# Attacker residual (Starknet account)
attacker_residual = {
 "ETH": 475.38*prices["ETH"], "STRK": 11.87e6*prices["STRK"], "WBTC": 0.36*prices["WBTC"],
 "DAI": 9080*prices["DAI"],
}

out = {
 "block": 15826705,
 "prices": prices,
 "market_cash_usd": cash_usd,
 "market_cash_total_usd": total_cash,
 "market_debt_usd": debt_usd,
 "market_debt_total_usd": total_debt,
 "pools_usd": pool_usd,
 "pools_total_usd": total_pools,
 "nststrk_vault_strk": nst_vault_strk,
 "nststrk_vault_usd": nst_vault_usd,
 "alpha_market_cash_usd": alpha,
 "alpha_market_cash_total_usd": alpha_total,
 "attacker_residual_starknet_usd": attacker_residual,
}
print(json.dumps(out, indent=1, default=str))
json.dump(out, open("final_numbers.json","w"), indent=1)
print(f"\nTOTAL market cash: ${total_cash:,.0f}")
print(f"TOTAL market debt: ${total_debt:,.0f}")
print(f"TOTAL pools:       ${total_pools:,.0f}")
print(f"nstSTRK vault:     ${nst_vault_usd:,.0f}")
print(f"Alpha cash:        ${alpha_total:,.0f}")
