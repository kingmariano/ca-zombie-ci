#!/usr/bin/env python3
"""C2-10 child verifier: recompute market-depth / capture numbers from raw evidence."""
import json, os, hashlib

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "verify_market_raw")
def L(name, default=None):
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        return default
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return default

def num(x, d=0.0):
    try:
        return float(x)
    except Exception:
        return d

DSM_IBCT = "ibc/EA4C0A9F72E2CEDF10D0E7A9A6A22954DB3444910DB5BE980DF59B05A46DAD1C"
ATOM_IBCT = "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2"
USDC_IBCT = "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4"

out = {"inputs": {}}

# ---- prices ----
cg = L("prices-coingecko.json", {})
ll = L("prices-llama.json", {}).get("coins", {})
p_dsm_cg = num(cg.get("desmos", {}).get("usd"))
p_atom_dl = num(ll.get("coingecko:cosmos", {}).get("price"))
p_osmo_dl = num(ll.get("coingecko:osmosis", {}).get("price"))
p_atom_cg = num(cg.get("cosmos", {}).get("usd"))
p_osmo_cg = num(cg.get("osmosis", {}).get("usd"))
out["prices"] = {"dsm_cg": p_dsm_cg, "dsm_market_cap_cg": num(cg.get("desmos", {}).get("usd_market_cap")),
                 "dsm_vol24h_cg": num(cg.get("desmos", {}).get("usd_24h_vol")),
                 "atom_dl": p_atom_dl, "osmo_dl": p_osmo_dl, "atom_cg": p_atom_cg, "osmo_cg": p_osmo_cg,
                 "llama_has_dsm": "coingecko:desmos" in ll}

# ---- desmos state ----
cp_api = L("desmos-api-community-pool-h.json", {})
stake = L("desmos-staketab-staking-pool-h.json", {})
supply = L("desmos-staketab-supply-h.json", {})
escrow_api = L("desmos-api-escrow-balances-h.json", {})
cp_dsm = num((cp_api.get("pool") or [{}])[0].get("amount")) / 1e6
bonded = num(stake.get("pool", {}).get("bonded_tokens")) / 1e6
not_bonded = num(stake.get("pool", {}).get("not_bonded_tokens")) / 1e6
total_supply = 0.0
for b in supply.get("supply", []):
    if b.get("denom") == "udsm":
        total_supply = num(b.get("amount")) / 1e6
escrow = num((escrow_api.get("balances") or [{}])[0].get("amount")) / 1e6
osmo_supply = num((L("osmo-dsm-supply.json", {}).get("amount") or {}).get("amount")) / 1e6
quorum_pct = num(json.loads(L("desmos-api-gov-params-quorum-h.json", {}).get("param", {}).get("value", "{}")).get("quorum"))
quorum_dsm = quorum_pct * bonded

out["desmos_state"] = {
    "height_pinned": 30863430,
    "cp_dsm": cp_dsm, "bonded_dsm": bonded, "not_bonded_dsm": not_bonded,
    "total_supply_dsm": total_supply, "escrow_c2_dsm": escrow, "osmo_dsm_supply": osmo_supply,
    "escrow_minus_supply": escrow - osmo_supply, "escrow_minus_supply_pct": 100 * (escrow - osmo_supply) / escrow,
    "quorum_pct": quorum_pct, "quorum_dsm": quorum_dsm,
    "cp_nominal_cg": cp_dsm * p_dsm_cg,
}

# ---- pools ----
gamm = L("osmo-gamm-all.json", {}).get("pools", [])
cl = L("osmo-cl-all.json", {}).get("pools", [])
pools = []
for p in gamm:
    if DSM_IBCT not in json.dumps(p):
        continue
    fee = num((p.get("pool_params") or {}).get("swap_fee"))
    assets = {}
    for a in (p.get("pool_assets") or p.get("pool_liquidity") or []):
        t = a.get("token") if isinstance(a, dict) and "token" in a else a
        if isinstance(t, dict) and t.get("denom"):
            assets[t["denom"]] = num(t.get("amount")) / 1e6
    dsm = assets.get(DSM_IBCT, 0.0)
    counter = {k: v for k, v in assets.items() if k != DSM_IBCT}
    pools.append({"id": p.get("id"), "type": "gamm", "fee": fee, "dsm": dsm, "counter": counter})
for p in cl:
    if DSM_IBCT not in json.dumps(p):
        continue
    pools.append({"id": p.get("id"), "type": "cl", "fee": num(p.get("spread_factor")),
                  "tick": p.get("current_tick"), "sqrt_price": p.get("current_sqrt_price"),
                  "liquidity": p.get("current_tick_liquidity"),
                  "token0": p.get("token0"), "token1": p.get("token1"),
                  "last_update": p.get("last_liquidity_update")})
# CL bank balances
clbal = L("cl1271-balances.json", {})
cl_bal = {b["denom"]: num(b["amount"]) for b in (clbal.get("balances") or [])}

# price counter assets
price = {ATOM_IBCT: (p_atom_dl, "ATOM"), "uosmo": (p_osmo_dl, "OSMO"), USDC_IBCT: (1.0, "USDC")}
for p in pools:
    if p["type"] != "gamm":
        continue
    for denom, amt in p["counter"].items():
        usd_per_unit = price.get(denom, (0.0, "?"))[0] / 1e6
        p.setdefault("counter_usd", {})[denom] = amt * usd_per_unit
        p.setdefault("implied_dsm", {})[denom] = amt * usd_per_unit / p["dsm"] if p["dsm"] else 0.0

# ---- (a) sell CP into each pool, constant product, fee on input ----
X = cp_dsm
sell = []
total_out = 0.0
for p in pools:
    if p["type"] == "gamm":
        D, fee = p["dsm"], p["fee"]
        out_usd = 0.0
        detail = {}
        for denom, amt in p["counter"].items():
            C = p.get("counter_usd", {}).get(denom, 0.0)
            xe = X * (1 - fee)
            o = C * xe / (D + xe) if (D + xe) > 0 else 0.0
            detail[denom] = o
            out_usd += o
        sell.append({"pool": p["id"], "type": "gamm", "fee": fee, "out_usd": out_usd, "detail": detail,
                     "near_drain_limit_usd": sum(p.get("counter_usd", {}).values())})
        total_out += out_usd
    else:
        # CL pool: can only extract the on-chain counter balance (token1 if DSM is token0)
        c_usd = 0.0
        for denom, amt in cl_bal.items():
            if denom == USDC_IBCT:
                c_usd += amt / 1e6 * 1.0
        sell.append({"pool": p["id"], "type": "cl", "fee": p["fee"], "out_usd": c_usd,
                     "cl_counter_balance_bound_usd": c_usd, "note": "bounded by pool bank balance; 22000 DSM in pool"})
        total_out += c_usd

counter_reserve_total = sum(sum(p.get("counter_usd", {}).values()) for p in pools if p["type"] == "gamm") + sum(
    (amm / 1e6 if d == USDC_IBCT else 0.0) for d, amm in cl_bal.items())
dsm_in_pools = sum(p.get("dsm", 0.0) for p in pools)

out["sell_cp"] = {
    "sell_amount_dsm": X,
    "per_pool": sell,
    "total_realizable_usd_at_prices": total_out,
    "theoretical_max_counter_reserves_usd": counter_reserve_total,
    "dsm_in_gamm_and_cl_pools": dsm_in_pools,
    "dsm_in_gamm_pools": sum(p["dsm"] for p in pools if p["type"] == "gamm"),
}

# ---- (b) buy quorum on market ----
q = quorum_dsm
out["buy_quorum"] = {"quorum_dsm": q, "pool_dsm_available": dsm_in_pools,
                     "max_fraction_of_quorum_obtainable": dsm_in_pools / q,
                     "infeasible": dsm_in_pools < q}
# cost to buy a few illustrative sizes (pro-rata, constant product)
def buy_cost(target):
    cost = 0.0
    ok = True
    for p in (pp for pp in pools if pp["type"] == "gamm"):
        D = p["dsm"]
        share = target * (D / dsm_in_pools)
        if share >= D:
            ok = False
            continue
        C = sum(p.get("counter_usd", {}).values())
        f = p["fee"]
        cost += C * (share / (D - share)) / (1 - f)
    return cost, ok

for t in [100_000, 400_000, 700_000, q]:
    c, ok = buy_cost(t)
    out["buy_quorum"][f"cost_buy_{t}"] = {"usd": c if ok else None, "partial_possible": ok}

# ---- (c) OTC lower bound ----
out["otc"] = {
    "quorum_at_cg_spot_usd": q * p_dsm_cg,
    "quorum_at_implied_618_usd": q * (pools[0].get("implied_dsm", {}).get(ATOM_IBCT, 0)),
    "outvote_top4_dsm": None,  # filled below
}
v = L("desmos-api-validators-bonded-h.json", {}).get("validators", [])
votes = sorted([num(x.get("tokens")) / 1e6 for x in v], reverse=True)
top4 = sum(votes[:4])
out["otc"]["outvote_top4_dsm"] = top4
out["otc"]["outvote_top4_at_cg_usd"] = top4 * p_dsm_cg

# ---- capture net ----
# attacker buys quorum OTC at spot, receives CP via proposal, dumps quorum+CP (=2q approx) into pools
bag = 2 * q
dump = 0.0
for p in (pp for pp in pools if pp["type"] == "gamm"):
    D = p["dsm"]; C = sum(p.get("counter_usd", {}).values()); f = p["fee"]
    xe = bag * (1 - f)
    dump += C * xe / (D + xe)
dump += sum((amm / 1e6) for d, amm in cl_bal.items() if d == USDC_IBCT)
out["capture"] = {
    "quorum_dsm": q, "cp_dsm": cp_dsm, "attacker_bag_dsm": bag + cp_dsm,
    "realizable_dump_usd": dump,
    "otc_cost_at_cg_usd": q * p_dsm_cg,
    "net_pnl_at_cg_usd": dump - q * p_dsm_cg,
    "breakeven_otc_price_usd": dump / q,
    "breakeven_vs_cg": (dump / q) / p_dsm_cg if p_dsm_cg else None,
}

print(json.dumps(out, indent=2))
with open(os.path.join(RAW, "verify_compute.json"), "w") as f:
    json.dump(out, f, indent=2)
