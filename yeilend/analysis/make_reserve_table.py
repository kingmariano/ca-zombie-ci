#!/usr/bin/env python3
"""Build the YeiLend reserve table: oracle vs DefiLlama market price, USD values, liquidity."""
import json, sys, urllib.request

d = json.load(open("analysis/reserves_raw.json"))
BLK = d["block"]

# DefiLlama prices for the underlying assets
assets = []
for p in d["pools"].values():
    for r in p["reserves"]:
        if r["asset"] not in assets:
            assets.append(r["asset"])
url = "https://coins.llama.fi/prices/current/" + ",".join("sei:" + a for a in assets)
with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30) as f:
    dl = json.load(f)["coins"]

def usd(amount, price1e8, dec):
    if amount is None or price1e8 is None:
        return None
    return amount / (10 ** dec) * price1e8 / 1e8

rows = []
for pname, p in d["pools"].items():
    for r in p["reserves"]:
        sym = r["symbol"]; dec = r["decimals"] or 18
        dlc = dl.get("sei:" + r["asset"], {})
        dlp = dlc.get("price")
        oracle_p = r["oraclePrice"] / 1e8 if r["oraclePrice"] is not None else None
        aSup = r.get("aToken_totalSupply"); vDebt = r.get("vDebtTotalSupply")
        aBal = r.get("aToken_underlying_balance")
        rows.append({
            "pool": pname, "symbol": sym, "asset": r["asset"],
            "aToken": r["aToken"], "vToken": r["variableDebtToken"],
            "ltv_pct": r["conf"]["ltv_bp"] / 100, "lt_pct": r["conf"]["lt_bp"] / 100,
            "bonus_pct": r["conf"]["bonus_bp"] / 100, "reserve_factor_pct": r["conf"]["reserveFactor_bp"] / 100,
            "liq_protocol_fee_pct": r["conf"]["liqProtocolFee_bp"] / 100,
            "active": r["conf"]["active"], "frozen": r["conf"]["frozen"], "paused": r["conf"]["paused"],
            "borrowing": r["conf"]["borrowingEnabled"], "eMode": r["conf"]["eModeCategory"],
            "forced_liq": r["conf"]["forcedLiquidationEnabled"],
            "borrowCap": r["conf"]["borrowCap"], "supplyCap": r["conf"]["supplyCap"],
            "oracle_price": oracle_p, "dl_price": dlp,
            "oracle_src": r["oracleSource"],
            "supply_tokens": aSup / (10 ** dec) if aSup is not None else None,
            "debt_tokens": vDebt / (10 ** dec) if vDebt is not None else None,
            "available_underlying": aBal / (10 ** dec) if aBal is not None else None,
            "supply_usd_oracle": usd(aSup, r["oraclePrice"], dec),
            "debt_usd_oracle": usd(vDebt, r["oraclePrice"], dec),
            "available_usd_oracle": usd(aBal, r["oraclePrice"], dec),
            "supply_usd_dl": usd(aSup, int(dlp * 1e8) if dlp else None, dec),
            "liquidity_index": r["liquidityIndex"] / 1e27,
        })

# markdown
with open("analysis/reserve_table.md", "w") as f:
    f.write(f"# YeiLend reserve table — Sei mainnet block {BLK} (oracle prices from pool oracles; DL = DefiLlama)\n\n")
    for pname in d["pools"]:
        f.write(f"## {pname}\n\n")
        f.write("| sym | asset | oracle$ | DL$ | LTV% | LT% | bonus% | RF% | aSupply | vDebt | avail | supply$ | debt$ | flags |\n")
        f.write("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for r in [x for x in rows if x["pool"] == pname]:
            flags = []
            if r["active"]: flags.append("act")
            if r["frozen"]: flags.append("FRZ")
            if r["paused"]: flags.append("PAUSE")
            if r["borrowing"]: flags.append("borr")
            if r["forced_liq"]: flags.append("FORCED")
            if r["eMode"]: flags.append(f"e{r['eMode']}")
            f.write("| {sym} | `{asset}` | {op} | {dp} | {ltv} | {lt} | {bo} | {rf} | {asup} | {vdebt} | {av} | {su} | {du} | {fl} |\n".format(
                sym=r["symbol"], asset=r["asset"][:10] + "…",
                op=f"{r['oracle_price']:.6f}" if r["oracle_price"] is not None else "-",
                dp=f"{r['dl_price']:.6f}" if r["dl_price"] is not None else "-",
                ltv=r["ltv_pct"], lt=r["lt_pct"], bo=r["bonus_pct"], rf=r["reserve_factor_pct"],
                asup=f"{r['supply_tokens']:,.2f}" if r["supply_tokens"] is not None else "-",
                vdebt=f"{r['debt_tokens']:,.2f}" if r["debt_tokens"] is not None else "-",
                av=f"{r['available_underlying']:,.2f}" if r["available_underlying"] is not None else "-",
                su=f"${r['supply_usd_oracle']:,.0f}" if r["supply_usd_oracle"] is not None else "-",
                du=f"${r['debt_usd_oracle']:,.0f}" if r["debt_usd_oracle"] is not None else "-",
                fl=",".join(flags)))
        f.write("\n")
json.dump({"block": BLK, "rows": rows}, open("analysis/reserve_table.json", "w"), indent=1)

# summary numbers
tot_supply = sum(r["supply_usd_oracle"] or 0 for r in rows)
tot_debt = sum(r["debt_usd_oracle"] or 0 for r in rows)
tot_avail = sum(r["available_usd_oracle"] or 0 for r in rows)
print(f"block {BLK}")
print(f"total supply (oracle): ${tot_supply:,.0f}")
print(f"total debt (oracle):   ${tot_debt:,.0f}")
print(f"available underlying (oracle): ${tot_avail:,.0f}")
for r in rows:
    if r["symbol"] in ("WSEI", "USDC", "USDT", "fastUSD", "sfastUSD", "USD₮0"):
        print(f"{r['symbol']:<9} oracle={r['oracle_price']} dl={r['dl_price']} supply={r['supply_tokens']:.2f} debt={r['debt_tokens']:.2f} avail={r['available_underlying']:.2f} avail$={r['available_usd_oracle']:.0f} flags=ltv{r['ltv_pct']}/lt{r['lt_pct']}/frozen={r['frozen']}/forced={r['forced_liq']}")
