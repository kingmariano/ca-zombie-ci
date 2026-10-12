#!/usr/bin/env python3
"""Exact integer-math simulation of FlareBank (Bank) sell-out by current holders.

Mirrors Bank.sol v0.1.3 (verified source, flare-explorer) at block 71924765+.
Read-only; arithmetic only.
"""
import json

# --- live state (read at latest block, see state2.json / live_reads.json) ---
SUPPLY = int("1fc3e361526df04f33f27", 16)          # 2,400,109.768e18
BAL    = int("f400d7fb18e09168fa50d", 16)          # 18,436,367.758e18
U      = int("82b1694c8ea7964d1286", 16)           # unclaimedDividendTotal
T      = int("21bdeaf9b251588d5970", 16)           # unclaimedTeamFees
F      = int("b3f4e533b7072d9c375", 16)            # unclaimedFeeReceiverFees
E18 = 10**18
TOKEN_PRICE_INITIAL = 1 * E18
TOKEN_PRICE_INCREMENTAL = 10**16
ETHER_INCEREMENT = 10000 * E18
MAX_BUY = 50001 * E18  # per-sell cap: taxedEth < MAX_BUY (50,001 NAT)
MAX_BIPS = 100_00
DIVIDEND_FEE = 10_00

def calc_price(balance_gross, is_buy, pools):
    U,T,F = pools
    if balance_gross < (F + T + U):
        return TOKEN_PRICE_INITIAL
    net = balance_gross - F - T - U
    increments = net // ETHER_INCEREMENT
    return TOKEN_PRICE_INITIAL + increments * TOKEN_PRICE_INCREMENTAL

def tokens_to_eth(s_tokens, supply, balance, pools):
    U,T,F = pools
    taxed = balance - U - T - F
    est_out = taxed * s_tokens // supply
    bg = balance - est_out if balance > est_out else 0
    worst = calc_price(bg, False, pools)
    return s_tokens * worst // E18

def sell(s_tokens, supply, balance, pools, growth=None):
    """Returns (eth_gross, taxed_eth, public_div, recv_fee, team_fee, new_pools, new_supply)"""
    U,T,F = pools
    eth = tokens_to_eth(s_tokens, supply, balance, pools)
    to_dist = eth * DIVIDEND_FEE // MAX_BIPS
    taxed_eth = eth - to_dist
    recv = to_dist * 5_00 // MAX_BIPS
    team = to_dist * 15_00 // MAX_BIPS
    public_div = to_dist - recv - team
    new_pools = (U + public_div + taxed_eth, T + team, F + recv)   # unclaimed += public_div + taxed_eth
    new_supply = supply - s_tokens
    # balance unchanged (WNat stays in contract until withdraw)
    return eth, taxed_eth, public_div, recv, team, new_pools, new_supply

def main():
    holders = json.load(open("/tmp/opencode/bank_holders_all.json"))
    hs = [(h["address"], int(h["value"])) for h in holders]
    hs = [(a,v) for a,v in hs if v > 0]
    hs.sort(key=lambda x: -x[1])
    supply, balance, pools = SUPPLY, BAL, (U, T, F)
    total_taxed = 0
    total_eth_gross = 0
    per = []
    for a, v in hs:
        v = min(v, supply)
        if v <= 0: continue
        holder_taxed = 0
        holder_gross = 0
        rem = v
        while rem > 0:
            chunk = rem
            while True:
                eth_c, taxed_c, pd_c, recv_c, team_c, pools_c, supply_c = sell(chunk, supply, balance, pools)
                if taxed_c < MAX_BUY or chunk <= E18:
                    break
                chunk = chunk * 95 // 100
            eth, taxed, pd, recv, team, pools, supply = eth_c, taxed_c, pd_c, recv_c, team_c, pools_c, supply_c
            holder_taxed += taxed; holder_gross += eth; rem -= chunk
        total_taxed += holder_taxed
        total_eth_gross += holder_gross
        per.append((a, v/E18, holder_taxed/E18))
    # WNat actually leaving the contract = sum of taxed_eth (withdrawable by sellers)
    # + dividends claimed by holders (public_div distributed pro-rata; assume all claimed)
    total_public = pools[0] - U - total_taxed
    print(f"holders simulated: {len(per)}")
    print(f"supply sold: {(SUPPLY-supply)/E18:,.2f} BANK")
    print(f"gross curve value: {total_eth_gross/E18:,.2f} WFLR")
    print(f"seller withdrawable (taxed): {total_taxed/E18:,.2f} WFLR")
    print(f"public dividends generated during sells: {total_public/E18:,.2f} WFLR")
    print(f"team fees now: {pools[1]/E18:,.2f} WFLR ; feeReceiver: {pools[2]/E18:,.2f} WFLR")
    print(f"remaining contract balance: {BAL/E18:,.2f} WFLR")
    print(f"remaining pool obligations: {sum(pools)/E18:,.2f} WFLR")
    print("top-5 sellers:")
    for a, v, t in per[:5]:
        print(f"   {a}  {v:,.2f} BANK -> {t:,.2f} WFLR")
    json.dump({"per":[{"addr":a,"bank":v,"wflr":t} for a,v,t in per],
               "total_taxed": total_taxed/E18, "total_gross": total_eth_gross/E18,
               "public_div_generated": total_public/E18,
               "final_pools": [p/E18 for p in pools],
               "remaining_supply": supply/E18},
              open("sellout_sim.json","w"), indent=1)

if __name__ == "__main__":
    main()
