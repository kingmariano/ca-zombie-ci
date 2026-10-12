#!/usr/bin/env python3
"""Quantify the only unprivileged value-capture paths found:
   A) take under-collateralized standing offers (debt_request_v2): net = UTxO value - required collateral
   B) fund expired requests (request_v1/v2) and liquidate at deadline: net = collateral - loan
Strict pricing: DefiLlama cardano:<unit> only (fallback coingecko for the biggest names, flagged).
"""
import json, urllib.request, urllib.parse, time, sys
from collections import defaultdict

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
CG = {
    "8fef2d34078659493ce161a6c7fba4b56afefa8535296a5743f69587441414441": "coingecko:aada-finance",
    "5d16cc1a177b5d9ba9cfa9793b07e60f1fb70fea1f8aef064415d114494147": "coingecko:iagon",
}


def http(url, timeout=45, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "readonly-research/1.0"})
            return json.loads(urllib.request.urlopen(req, timeout=timeout).read())
        except Exception as e:
            time.sleep(1 + i)
    return {}


r = http("https://coins.llama.fi/prices/current/coingecko:cardano")
ADA = (r.get("coins") or {}).get("coingecko:cardano", {}).get("price")
print("ADA", ADA)

rows = json.load(open(f"{D}/live_utxos_classified.json"))
utxos = json.load(open(f"{D}/koios_address_utxos.json"))
decimals = {}
for u in utxos:
    for a in (u.get("asset_list") or []):
        decimals[a["policy_id"] + a["asset_name"]] = int(a.get("decimals") or 0)

units = set()
for r0 in rows:
    L = r0.get("loan")
    if L:
        for field in ("loan_asset", "collateral_asset", "interest_asset"):
            cs, tn = L[field]
            units.add(cs + tn)
prices = {}
ul = sorted(units)
for i in range(0, len(ul), 40):
    enc = ",".join(urllib.parse.quote("cardano:" + u, safe="") for u in ul[i:i + 40])
    rr = http("https://coins.llama.fi/prices/current/" + enc)
    for k, v in (rr.get("coins") or {}).items():
        prices[k.replace("cardano:", "", 1)] = v.get("price")
for u in ul:
    if prices.get(u) is None and u in CG:
        rr = http("https://coins.llama.fi/prices/current/" + urllib.parse.quote(CG[u], safe=""))
        prices[u] = (rr.get("coins") or {}).get(CG[u], {}).get("price")
prices[""] = ADA  # ADA unit = empty policy+name
decimals[""] = 6


def usd_unit(unit, amt):
    p = prices.get(unit)
    if p is None:
        return None
    return amt / (10 ** decimals.get(unit, 0)) * p


print("\n=== debt_request_v2 offers (take path) ===")
take_total = 0.0
for r0 in rows:
    if r0["addr"] != "debt_request_v2":
        continue
    L = r0.get("loan")
    utxo_usd = r0["ada"] * ADA + (sum(usd_unit(k.split(".")[0] + k.split(".")[1], v) or 0 for k, v in r0["assets"].items()))
    if not L:
        print(f'  {r0["tx"][:12]}#{r0["ix"]}: no datum, utxo ${utxo_usd:.2f} (unspendable/unknown)')
        continue
    loan_cs, loan_tn = L["loan_asset"]; coll_cs, coll_tn = L["collateral_asset"]
    need = usd_unit(coll_cs + coll_tn, L["collateralAmnt"] or 0)
    exp = L["requestExpiration_ms"] or 0
    expired = exp < time.time() * 1000
    net = None
    if need is not None:
        net = utxo_usd - need
    print(f'  {r0["tx"][:12]}#{r0["ix"]}: utxo=${utxo_usd:8.2f} need_coll=${ (need if need is not None else -1):8.2f} '
          f'expired={expired} lenderNft={L["lenderNftTn"][:10]} net_if_take={net if net is None else round(net,2)}')
    if net is not None and net > 0 and expired:
        take_total += net
print("TOTAL under-collateralized take value (positive-net, expired):", round(take_total, 2))

print("\n=== request_v1 / request_v2 (fund+liquidate equity) ===")
fund_total = 0.0
for r0 in rows:
    if r0["addr"] not in ("request_v1", "request_v2"):
        continue
    L = r0.get("loan")
    if not L:
        print(f'  {r0["addr"]} {r0["tx"][:12]}#{r0["ix"]}: no datum (dust)')
        continue
    lcs, ltn = L["loan_asset"]; ccs, ctn = L["collateral_asset"]
    loan_usd = usd_unit(lcs + ltn, L["loanAmnt"] or 0)
    coll_usd = usd_unit(ccs + ctn, L["collateralAmnt"] or 0)
    exp = (L["requestExpiration_ms"] or 0)
    expired = exp < time.time() * 1000 if exp else False
    dur_h = (L["loanDuration_ms"] or 0) / 3.6e6
    lender = L["lenderNftTn"]
    equity = (coll_usd - loan_usd) if (loan_usd is not None and coll_usd is not None) else None
    print(f'  {r0["addr"]} {r0["tx"][:12]}#{r0["ix"]}: utxo_ada={r0["ada"]:9.2f} loan=${loan_usd if loan_usd is None else round(loan_usd,2)} '
          f'coll=${coll_usd if coll_usd is None else round(coll_usd,2)} dur={dur_h:.1f}h expired={expired} equity={equity if equity is None else round(equity,2)} lenderNft={lender[:8]}')
    if equity and equity > 0 and lender == "ff":
        fund_total += equity
print("TOTAL fund+liquidate equity (positive, expired, unfunded):", round(fund_total, 2))
