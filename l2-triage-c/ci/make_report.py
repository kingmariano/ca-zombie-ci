#!/usr/bin/env python3
"""Turn ci-out/results.json into a markdown table + summary.json skeleton."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "ci-out", "results.json")))
rows = res["rows"]
rows.sort(key=lambda r: -(r.get("live_usd") or 0))

STATUS_MAP = {
    "LIVE-FUNDED": "LIVE-FUNDED",
    "DRAINED": "DRAINED/$0",
    "UNREACHABLE": "UNREACHABLE",
}

print("| # | Protocol | Chain | Status | Live $ (cash custody) | Key custody | Evidence | Conf |")
print("|---|---|---|---|---|---|---|---|")
for i, r in enumerate(rows, 1):
    usd = r.get("live_usd")
    usd_s = f"${usd:,.0f}" if usd else "$0"
    cust = "; ".join(str(c) for c in r.get("custody", []))[:110]
    ev = []
    e = r.get("evidence", {})
    for k in ("block", "ledger_state", "pairs_parsed", "amm_pools_parsed", "vaults", "accounts",
              "confirmed_sats", "history_entries", "cash_usd_contract_oracle", "pool_fil",
              "total_lovelace", "balance_source", "source", "balance_source"):
        if k in e and e[k] is not None:
            ev.append(f"{k}={e[k]}")
    for k in ("reserves", "fungibles", "market_detail", "orml_tokens_scaled", "lsu_redemption"):
        if k in e:
            v = e[k]
            ev.append(f"{k}:{len(v) if hasattr(v,'__len__') else v}")
    ev_s = ", ".join(ev)[:150]
    print(f"| {i} | {r['protocol']} | {r['chain']} | {STATUS_MAP.get(r['status'], r['status'])} | {usd_s} | {cust} | {ev_s} | {r['confidence']} |")
