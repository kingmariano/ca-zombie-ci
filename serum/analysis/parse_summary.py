#!/usr/bin/env python3
"""Post-process serum_v3_markets_raw.json: prices via DefiLlama, USD totals, CSV/JSON."""
import csv, json, os, sys, time, urllib.request

OUT = "/home/heisenberg/CA/serum/analysis"
raw = json.load(open(os.path.join(OUT, "serum_v3_markets_raw.json")))
markets = [m for m in raw["markets"] if not (m.get("closed") or m.get("parse_error"))]

# collect mints
mints = set()
for m in markets:
    for side in ("coin", "pc"):
        mint = m.get(f"{side}_vault_mint")
        if mint:
            mints.add(mint)
print("unique mints:", len(mints))

# DefiLlama prices in batches
prices = {}
ml = sorted(mints)
for i in range(0, len(ml), 40):
    part = ml[i:i+40]
    url = "https://coins.llama.fi/prices/current/" + ",".join("solana:" + x for x in part)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=45) as r:
                j = json.loads(r.read().decode())
            for k, v in (j.get("coins") or {}).items():
                prices[k.split(":")[-1]] = v
            break
        except Exception as e:
            if attempt == 3:
                print("price fetch fail", part[:3], e)
            time.sleep(2 * (attempt + 1))
    time.sleep(0.3)
print("priced mints:", len(prices))
with open(os.path.join(OUT, "mint_prices.json"), "w") as f:
    json.dump(prices, f, indent=1)

# compute per-market USD
rows = []
tot_usd = 0.0
side_tot = {}
for m in markets:
    usd = 0.0
    parts = []
    for side in ("coin", "pc"):
        amt = m.get(f"{side}_vault_amount")
        mint = m.get(f"{side}_vault_mint")
        if amt is None or not mint:
            continue
        p = prices.get(mint, {})
        price = p.get("price")
        dec = p.get("decimals", m.get(f"{side}_vault_decimals"))
        sym = p.get("symbol", mint[:6])
        usdv = (amt / (10 ** dec) * price) if (price and dec is not None) else None
        m[f"{side}_usd"] = usdv
        m[f"{side}_symbol"] = sym
        m[f"{side}_price"] = price
        if usdv:
            usd += usdv
            t = side_tot.setdefault(mint, {"symbol": sym, "amount": 0, "usd": 0.0, "decimals": dec})
            t["amount"] += amt
            t["usd"] += usdv
        parts.append(f"{amt}/{sym}")
    m["vault_usd"] = round(usd, 2)
    tot_usd += usd
    rows.append(m)
    # sanity: actual vault vs deposits+fees
    for side in ("coin", "pc"):
        va = m.get(f"{side}_vault_amount")
        dt = m.get(f"{side}_deposits_total")
        fees = m.get(f"{side}_fees_accrued")
        if va is not None and dt is not None:
            diff = va - dt - (fees or 0)
            if abs(diff) > 0:
                m[f"{side}_vault_minus_accounted"] = diff

rows.sort(key=lambda m: -(m.get("vault_usd") or 0))
print(f"\nTOTAL vault USD (168 registry markets): ${tot_usd:,.2f}")
print("\nTop 15 markets by vault USD:")
for m in rows[:15]:
    print(f"  {m.get('name','?'):24s} {m['address']}  ${m.get('vault_usd',0):,.2f}")

print("\nTop 25 mints by USD:")
for mint, t in sorted(side_tot.items(), key=lambda kv: -kv[1]["usd"])[:25]:
    print(f"  {t['symbol']:10s} {mint}  amount={t['amount']}  usd=${t['usd']:,.2f}")

# CSV
cols = ["address", "name", "flags", "deprecated", "vault_usd", "coin_symbol", "coin_mint",
        "coin_vault_amount", "coin_deposits_total", "coin_fees_accrued",
        "pc_symbol", "pc_mint", "pc_vault_amount", "pc_deposits_total", "pc_fees_accrued",
        "coin_lot_size", "pc_lot_size", "fee_rate_bps", "referrer_rebates_accrued",
        "vault_signer_nonce", "market_lamports", "coin_vault", "pc_vault",
        "coin_vault_lamports", "pc_vault_lamports", "coin_vault_minus_accounted", "pc_vault_minus_accounted"]
with open(os.path.join(OUT, "serum_v3_markets.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
    w.writeheader()
    for m in rows:
        w.writerow(m)

summary = {
    "slot": raw["slot"],
    "epoch": raw["epoch"],
    "fetched_at_utc": raw["fetched_at_utc"],
    "registry_markets": len(raw["markets"]),
    "initialized_markets": sum(1 for m in rows if (m.get("flags", 0) & 3) == 3),
    "disabled_markets": sum(1 for m in rows if m.get("flags", 0) & 128),
    "total_vault_usd": round(tot_usd, 2),
    "mint_totals": {k: {kk: vv for kk, vv in v.items()} for k, v in side_tot.items()},
    "extras": raw.get("extras"),
}
with open(os.path.join(OUT, "serum_v3_summary_raw.json"), "w") as f:
    json.dump(summary, f, indent=1)
json.dump(rows, open(os.path.join(OUT, "serum_v3_markets.json"), "w"), indent=1)
print("\nwrote serum_v3_markets.json / .csv / serum_v3_summary_raw.json")
