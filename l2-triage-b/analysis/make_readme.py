#!/usr/bin/env python3
"""Generate markdown tables for l2-triage-b/README.md from analysis/final_table.json."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = json.load(open(os.path.join(ROOT, "analysis/final_table.json")))
plan = json.load(open(os.path.join(ROOT, "ci/plan.json")))

# stale funds column from the split (for the watchlist comparison)
split = json.load(open(os.path.join(ROOT, "../ci/L2-SPLIT-B.json")))
stale = {r["protocol"].lower(): r for r in split}


def fmt(x):
    return f"${x:,.0f}" if x else "$0"


print("## Per-row live status (sorted by live $ desc)\n")
print("| # | Protocol | Chain(s) | Status | Live $ (on-chain) | DefiLlama $ (today) | Stale watchlist $ | Key contracts / evidence | Conf |")
print("|---|---|---|---|---|---|---|---|---|")
for i, r in enumerate(rows, 1):
    st = stale.get(r["name"].lower(), {})
    stale_f = st.get("funds", "—")
    ev = []
    for t in r["targets"][:3]:
        bits = t["label"]
        if t.get("pairs"):
            bits += f" ({t['pairs']} pairs)"
        if t.get("pools"):
            bits += f" ({t['pools']} pools)"
        if t.get("markets"):
            bits += f" ({t['markets']} markets)"
        ev.append(bits)
    evs = "; ".join(ev)[:150]
    dl = fmt(r["defillama_usd"]) + ("" if r["defillama_fresh"] else " (stale)")
    print(f"| {i} | {r['name']} | {','.join(r['chains'])} | {r['status']} | {fmt(r['onchain_usd'])} | {dl} | {stale_f} | {evs} | |")

print("\n## Phase-2 shortlist (funded, not covered)\n")
print("| Rank | Protocol | Chain(s) | Live $ | Why |")
print("|---|---|---|---|---|")
for i, r in enumerate([x for x in rows if x["status"].startswith("LIVE")], 1):
    print(f"| {i} | {r['name']} | {','.join(r['chains'])} | {fmt(r['onchain_usd'])} | live custody verified on-chain; {r['status'].lower()} |")

print("\n## Totals\n")
live = sum(r["onchain_usd"] for r in rows if r["status"].startswith("LIVE"))
print(f"- live total: {fmt(live)}")
print(f"- funded: {sum(1 for r in rows if r['status'].startswith('LIVE'))}")
print(f"- drained: {sum(1 for r in rows if r['status'].startswith('DRAINED'))}")
print(f"- unreachable: {sum(1 for r in rows if r['status'] == 'UNREACHABLE')}")
