#!/usr/bin/env python3
"""Extract reserve table + market stats from the live market object dump."""
import json, sys, time
d = json.load(open("/home/heisenberg/CA/suilend/analysis/market_raw.json"))
f = d["data"]["content"]["fields"]
now = int(time.time())
rows = []
tot_avail_usd = tot_dep_usd = tot_borrow_usd = 0.0
for r in f["reserves"]:
    x = r["fields"]
    cfg = x["config"]["fields"]["element"]["fields"]
    price = int(x["price"]["fields"]["value"]) / 1e18  # USD per whole token
    dec = int(x["mint_decimals"])
    avail = int(x["available_amount"]) / 10**dec
    borr = int(x["borrowed_amount"]["fields"]["value"]) / 1e18
    csup = int(x["ctoken_supply"]) / 10**dec
    fresh = now - int(x["price_last_update_timestamp_s"])
    coin = x["coin_type"]["fields"]["name"]
    rows.append({
        "idx": int(x["array_index"]),
        "coin": coin,
        "price_usd": price,
        "avail": avail,
        "avail_usd": avail * price,
        "borrowed": borr,
        "borrowed_usd": borr * price,
        "ctoken_supply": csup,
        "fresh_s": fresh,
        "open_ltv": int(cfg["open_ltv_pct"]),
        "close_ltv": int(cfg["close_ltv_pct"]),
        "max_close_ltv": int(cfg["max_close_ltv_pct"]),
        "liq_bonus_bps": int(cfg["liquidation_bonus_bps"]),
        "max_liq_bonus_bps": int(cfg["max_liquidation_bonus_bps"]),
        "proto_fee_bps": int(cfg["protocol_liquidation_fee_bps"]),
        "borrow_weight_bps": int(cfg["borrow_weight_bps"]),
        "isolated": bool(cfg["isolated"]),
        "spread_bps": int(cfg["spread_fee_bps"]),
        "borrow_fee_bps": int(cfg["borrow_fee_bps"]),
        "unclaimed_spread": int(x["unclaimed_spread_fees"]["fields"]["value"]) / 1e18,
    })
    tot_avail_usd += rows[-1]["avail_usd"]
    tot_borrow_usd += rows[-1]["borrowed_usd"]
    tot_dep_usd += rows[-1]["avail_usd"] + rows[-1]["borrowed_usd"]

rows.sort(key=lambda r: r["avail_usd"], reverse=True)
json.dump(rows, open("/home/heisenberg/CA/suilend/analysis/reserves.json", "w"), indent=1)
print(f"reserves={len(rows)} avail_usd={tot_avail_usd:,.0f} borrowed_usd={tot_borrow_usd:,.0f} total_usd={tot_dep_usd:,.0f}")
print(f"market version={f['version']} bad_debt_usd={f['bad_debt_usd']['fields']['value']} bad_debt_limit_usd={f['bad_debt_limit_usd']['fields']['value']}")
print(f"obligations={f['obligations']['fields']['size']}")
print(f"fee_receiver={f['fee_receiver']}")
print(f"rate_limiter: max_outflow={f['rate_limiter']['fields']['config']['fields']['max_outflow']} window={f['rate_limiter']['fields']['config']['fields']['window_duration']}s cur={f['rate_limiter']['fields']['cur_qty']['fields']['value']}")
print()
print(f"{'idx':>3} {'coin':<28} {'avail':>16} {'availUsd':>12} {'borrUsd':>12} {'fresh_s':>8} {'oLTV':>4} {'cLTV':>4} {'bonus':>5} {'fee':>4} {'w':>5}")
for r in rows:
    c = r["coin"].split("::")[-1][:26]
    print(f"{r['idx']:>3} {c:<28} {r['avail']:>16,.2f} {r['avail_usd']:>12,.0f} {r['borrowed_usd']:>12,.0f} {r['fresh_s']:>8} {r['open_ltv']:>4} {r['close_ltv']:>4} {r['liq_bonus_bps']:>5} {r['proto_fee_bps']:>4} {r['borrow_weight_bps']:>5}")
