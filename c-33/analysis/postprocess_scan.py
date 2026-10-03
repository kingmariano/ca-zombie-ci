#!/usr/bin/env python3
"""Post-process a ci-out/scan.json to apply the final predicate corrections
without re-running the whole scan:

  1. direct-drain free pull is bounded by the market's cash (a transfer cannot
     exceed getCash()); clear directDrain when the bounded pull is dust.
  2. emptyBorrowAttack requires totalSupply == 0 (the attacker must own all supply).
Then recompute per-target aggregates and the summary exposure list.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "ci-out", "scan.json")
d = json.load(open(p))
results = d["results"]

for t in results:
    borrowable = 0.0
    flagged = 0
    for m in t.get("markets", []):
        ts = m.get("totalSupply")
        cash = m.get("cash")
        if ts is not None and ts > 0:
            m["emptyBorrowAttack"] = False
        if m.get("directDrain"):
            fp = m.get("freePullRaw")
            if fp is not None and cash is not None:
                fp = min(fp, cash)
                m["freePullRaw"] = fp
                if m.get("price") and m.get("decimals") is not None:
                    m["freePullUSD"] = round(fp / (10 ** m["decimals"]) * m["price"], 6)
            if not m.get("freePullUSD") or m["freePullUSD"] < 0.01:
                m["directDrain"] = False
        if m.get("emptyBorrowAttack") or m.get("directDrain"):
            flagged += 1
        if (m.get("listed") and m.get("borrowPaused") is False and
                m.get("hasCode") is not False and m.get("cashUSD") is not None):
            avail = m["cashUSD"]
            if m.get("borrowCap") and m["borrowCap"] > 0 and m.get("price"):
                raw_avail = max(0, m["borrowCap"] - (m.get("totalBorrows") or 0))
                avail = min(avail, raw_avail * m["price"])
            borrowable += max(0.0, avail)
    t["borrowableCashUSD"] = round(borrowable, 2)
    t["flaggedMarkets"] = flagged

# rebuild exposure
cand = []
for t in results:
    bad = [m for m in t.get("markets", [])
           if m.get("directDrain") or m.get("emptyBorrowAttack") or
           (m.get("criticalSupply") and m.get("hasCode") is not False)]
    if not bad:
        continue
    empty_ready = any(m.get("emptyBorrowAttack") for m in bad)
    drain = sum(m.get("cashUSD") or 0 for m in bad if m.get("directDrain"))
    cand.append(dict(protocol=t["protocol"], chain=t["chain"], comptroller=t["comptroller"],
                     status=t["status"], borrowableCashUSD=t.get("borrowableCashUSD"),
                     mode=("empty_market_borrow" if empty_ready else "") + ("+direct_drain" if drain else "") or "near_empty_only",
                     directDrainUSD=round(drain, 2),
                     potentialUSD=round(drain + (t.get("borrowableCashUSD") or 0) if empty_ready else drain, 2)))
cand.sort(key=lambda x: -(x["potentialUSD"] or 0))

s = d["summary"]
s["empty_borrow_attack_markets"] = sum(1 for t in results for m in t.get("markets", []) if m.get("emptyBorrowAttack"))
s["direct_drain_markets"] = sum(1 for t in results for m in t.get("markets", []) if m.get("directDrain"))
s["exposure"] = cand
s["postprocessed"] = "T=0 rule + cash-bounded direct drain"
json.dump(d, open(p, "w"), indent=1)
json.dump(s, open(os.path.join(os.path.dirname(p), "scan_summary.json"), "w"), indent=1)
print("post-processed", p)
print("emptyAtk:", s["empty_borrow_attack_markets"], "direct:", s["direct_drain_markets"])
for e in cand[:6]:
    print(e["protocol"], e["chain"], e["mode"], e["potentialUSD"])
