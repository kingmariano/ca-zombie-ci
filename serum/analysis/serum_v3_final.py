#!/usr/bin/env python3
"""Final aggregates: per-mint totals (vault + deposits/fees/rebates), identity checks,
DefiLlama comparison, corrected rent. Read-only local computation."""
import json

A = "/home/heisenberg/CA/serum/analysis"
rows = json.load(open(f"{A}/serum_v3_markets.json"))
prices = json.load(open(f"{A}/mint_prices.json"))
rent = json.load(open(f"{A}/serum_v3_rent.json"))
dl = json.load(open(f"{A}/defillama_serum_latest_tokens.json"))
WSOL = "So11111111111111111111111111111111111111112"

agg = {}
ident_bad = []
ident_ok = 0
for m in rows:
    for side in ("coin", "pc"):
        va = m.get(f"{side}_vault_amount")
        dt = m.get(f"{side}_deposits_total")
        fe = m.get(f"{side}_fees_accrued")
        if va is None or dt is None:
            continue
        reb = (m.get("referrer_rebates_accrued") or 0) if side == "pc" else 0
        diff = va - dt - (fe or 0) - reb
        if diff == 0:
            ident_ok += 1
        else:
            ident_bad.append({"market": m.get("name"), "address": m["address"], "side": side, "diff": diff})
        mint = m.get(f"{side}_vault_mint")
        if not mint:
            continue
        t = agg.setdefault(mint, {"symbol": None, "decimals": None, "vault": 0, "deposits": 0, "fees": 0, "rebates": 0})
        t["vault"] += va
        t["deposits"] += dt
        t["fees"] += (fe or 0)
        t["rebates"] += reb
        p = prices.get(mint, {})
        if p.get("symbol"):
            t["symbol"] = p["symbol"]
        if p.get("decimals") is not None:
            t["decimals"] = p["decimals"]

# USD per mint (vault) and (deposits+fees)
tot_vault_usd = 0.0
tot_df_usd = 0.0
for mint, t in agg.items():
    p = prices.get(mint, {})
    price = p.get("price")
    dec = p.get("decimals", t.get("decimals"))
    if price and dec is not None:
        t["vault_usd"] = t["vault"] / 10 ** dec * price
        t["deposits_fees_usd"] = (t["deposits"] + t["fees"]) / 10 ** dec * price
        tot_vault_usd += t["vault_usd"]
        tot_df_usd += t["deposits_fees_usd"]

print(f"markets={len(rows)} identity_ok={ident_ok} identity_bad={len(ident_bad)}")
for b in ident_bad[:10]:
    print("  BAD", b)
print(f"TOTAL vault USD = ${tot_vault_usd:,.2f}; deposits+fees USD = ${tot_df_usd:,.2f}")

# DefiLlama comparison (top DL tokens)
alias = {"USDC": "usdc", "SOL": "SOL", "WETH": "WETH", "USDT": "usdt", "RLB": "RLB", "RAY": "ray",
         "ORCA": "orca", "MSOL": "msol", "SAMO": "samo", "STNK": None, "SOUSDT": "soUSDT",
         "WOOF": "WOOF", "CHEEMS": "CHEEMS", "CATO": "CATO", "MSOL ": "msol"}
sym2mint = {}
for mint, t in agg.items():
    s = (t.get("symbol") or "").lower()
    if s and s not in sym2mint:
        sym2mint[s] = mint
dlt = dl["tokens_last"]; dlu = dl["tokensInUsd_last"]
comp = []
for sym, usd in sorted(dlu.items(), key=lambda kv: -kv[1])[:20]:
    our_mint = sym2mint.get(sym.lower())
    our = agg.get(our_mint) if our_mint else None
    comp.append({
        "dl_symbol": sym, "dl_usd": round(usd, 2), "dl_amount": dlt.get(sym),
        "our_mint": our_mint,
        "our_vault_usd": round(our["vault_usd"], 2) if our and our.get("vault_usd") else None,
        "our_deposits_fees_usd": round(our["deposits_fees_usd"], 2) if our and our.get("deposits_fees_usd") else None,
    })
print("\nDL vs measured top tokens:")
for c in comp:
    print(f"  {c['dl_symbol']:8s} DL=${c['dl_usd']:>12,.2f}  ours_DF=${c['our_deposits_fees_usd']}  {c['our_mint']}")

# corrected rent
tot = rent["totals_lamports"]
extra = 0
wrapped = 0
for m in rows:
    for side in ("coin", "pc"):
        if m.get(f"{side}_vault_mint") == WSOL:
            wrapped += m.get(f"{side}_vault_amount") or 0
vault_rent = tot["vaults"] - wrapped
market_base = 398 * 3591360
out = {
    "market_count": len(rows),
    "total_vault_usd": round(tot_vault_usd, 2),
    "total_deposits_fees_usd": round(tot_df_usd, 2),
    "identity_ok_sides": ident_ok, "identity_bad": ident_bad,
    "mint_aggregates": agg,
    "defillama_comparison": comp,
    "rent": {
        "raw_sums_lamports": tot,
        "market_base_rent_lamports": market_base,
        "market_extra_lamports": tot["market"] - market_base,
        "sub_req_q_lamports": tot["req_q"], "sub_event_q_lamports": tot["event_q"],
        "sub_bids_lamports": tot["bids"], "sub_asks_lamports": tot["asks"],
        "vault_lamports_including_wrapped_sol": tot["vaults"],
        "wrapped_sol_in_vaults_raw": wrapped,
        "vault_rent_lamports_true": vault_rent,
        "total_true_rent_lamports": market_base + tot["req_q"] + tot["event_q"] + tot["bids"] + tot["asks"] + vault_rent,
    },
}
out["rent"]["total_true_rent_sol"] = out["rent"]["total_true_rent_lamports"] / 1e9
json.dump(out, open(f"{A}/serum_v3_final.json", "w"), indent=1)
print("\nRENT (SOL):", json.dumps({k: (v/1e9 if isinstance(v, int) and k.endswith('lamports') else v) for k, v in out["rent"].items() if k != 'raw_sums_lamports'}, indent=1))
print("wrote serum_v3_final.json")
