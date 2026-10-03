#!/usr/bin/env python3
"""C-24 refined category classification (theft vs early self-withdrawal).

For each locker token with balance B and USD v:
  buggy family:
    - non-owner future-locked records are replayable -> owner can take B
      * entitlement = min(B, sum of that wallet's own record amounts on the token)
      * E-U (theft of others' funds) += B - entitlement
      * H-O (own funds, early)      += entitlement
    - if no future non-owner record: H-O += min(B, sum expired non-owner amounts)
    - owner(attacker) records: P += B if any owner record amount <= B (contested pot)
  fixed family:
    H-O += min(B, sum expired non-owner amounts); S += B - H-O
  variant family:
    H-O += B (single claims pay recorded amounts; probe: 82-84% claimable)
  V3 escrows: per record share by lockTime (H-O if passed, else S)
Outputs ci-out/final_categories.json.
"""
import json, os, time

OUT = os.environ.get("CI_OUT", "ci-out")
os.makedirs(OUT, exist_ok=True)
now = int(time.time())

FAMILY = {
    "bsc_v1_0xEb3a": ("buggy", "bsc", "0xc4574ddef299e7e563971e200433e592eeaafa69"),
    "bsc_0x8655": ("fixed", "bsc", "0xc4574ddef299e7e563971e200433e592eeaafa69"),
    "bsc_0x5b5e": ("fixed", "bsc", "0xc4574ddef299e7e563971e200433e592eeaafa69"),
    "bsc_0x2D04": ("variant", "bsc", "0xc4574ddef299e7e563971e200433e592eeaafa69"),
    "bsc_0x81E0": ("variant", "bsc", "0xc4574ddef299e7e563971e200433e592eeaafa69"),
    "eth_v1_0x1Ba0": ("buggy", "ethereum", "0x06842629170d420a1f29a2bd8271ae7d8c3e860b"),
    "eth_0xc68C": ("fixed", "ethereum", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "eth_0xe740": ("fixed", "ethereum", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "eth_0x916a": ("variant", "ethereum", "0x06842629170d420a1f29a2bd8271ae7d8c3e860b"),
    "eth_0xBae2": ("variant", "ethereum", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "poly_v1_0xEb3a": ("buggy", "polygon", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "poly_0x6FCC": ("fixed", "polygon", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "poly_0x0360": ("fixed", "polygon", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "poly_0xb556": ("variant", "polygon", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "arb_0x51f4": ("fixed", "arbitrum", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "avax_0x77D0": ("fixed", "avax", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "avax_0x10f4": ("variant", "avax", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "gnosis_0x832C": ("fixed", "xdai", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
    "gnosis_0x554d": ("variant", "xdai", "0x47bacf935066b802eaa0067ec14ab035b24eb78b"),
}

def main():
    val = json.load(open(f"{OUT}/valuation.json")) if os.path.exists(f"{OUT}/valuation.json") else {}
    result = {"generated_at": now, "lockers": [], "v3": {}, "totals": {}, "theft_candidates": []}
    eu = p = ho = s = 0.0
    for fn, (family, chain, owner) in FAMILY.items():
        path = f"{OUT}/{fn}.json"
        if not os.path.exists(path):
            continue
        d = json.load(open(path))
        records, tokens = d.get("records", []), d.get("tokens", [])
        usd_by_token = {}
        if fn + ".json" in val:
            for row in val[fn + ".json"]["rows"]:
                usd_by_token[row["lp"].lower()] = row["usd"]
        total = sum(usd_by_token.get(t["lp"].lower(), 0) for t in tokens)
        locker = {"file": fn, "family": family, "chain": chain, "custody_usd": round(total, 2),
                  "eu_theft_usd": 0.0, "ho_usd": 0.0, "p_usd": 0.0, "s_usd": 0.0}
        for t in tokens:
            bal = int(t["balance"])
            if bal <= 0:
                continue
            lp = t["lp"].lower()
            usd = usd_by_token.get(lp, 0)
            if usd <= 0:
                continue
            recs = [r for r in records if r["lp"].lower() == lp and r["locked"] and int(r["amount"]) > 0]
            nonowner = [r for r in recs if r["wallet"].lower() != owner]
            ownerrecs = [r for r in recs if r["wallet"].lower() == owner]
            future = [r for r in nonowner if r["lockedTime"] > now and int(r["amount"]) <= bal]
            expired = [r for r in nonowner if r["lockedTime"] <= now and int(r["amount"]) <= bal]
            if family == "buggy":
                if future:
                    # the replaying wallet's own entitlement on this token:
                    # all of its records (future + expired, still locked) on this token
                    wallets = set(r["wallet"].lower() for r in future)
                    ent = 0
                    for w in wallets:
                        ent += sum(int(r["amount"]) for r in recs if r["wallet"].lower() == w)
                    ent = min(ent, bal)
                    theft = usd * (bal - ent) / bal if bal else 0
                    own = usd - theft
                    locker["eu_theft_usd"] += theft
                    locker["ho_usd"] += own
                    if theft > 100:
                        top = max(future, key=lambda r: int(r["amount"]))
                        result["theft_candidates"].append({
                            "locker": fn, "token": lp, "balance": bal, "usd": round(usd, 2),
                            "theft_usd": round(theft, 2), "wallet": top["wallet"], "idx": top["idx"],
                            "amount": top["amount"], "lockedTime": top["lockedTime"],
                            "n_future_records": len(future), "n_records_total": len(recs)})
                else:
                    claimable = min(bal, sum(int(r["amount"]) for r in expired))
                    locker["ho_usd"] += usd * claimable / bal if bal else 0
                    locker["s_usd"] += usd * (bal - claimable) / bal if bal else 0
                if ownerrecs and any(int(r["amount"]) <= bal for r in ownerrecs):
                    locker["p_usd"] += usd  # contested with EU/HO; owner can take whole balance
            elif family == "variant":
                locker["ho_usd"] += usd
            else:  # fixed
                claimable = min(bal, sum(int(r["amount"]) for r in expired))
                locker["ho_usd"] += usd * claimable / bal if bal else 0
                locker["s_usd"] += usd * (bal - claimable) / bal if bal else 0
        eu += locker["eu_theft_usd"]; ho += locker["ho_usd"]; p += locker["p_usd"]; s += locker["s_usd"]
        result["lockers"].append(locker)
    # V3
    v3_total = v3_ho = v3_future = 0.0
    if os.path.exists(f"{OUT}/v3_bsc.json"):
        v3 = json.load(open(f"{OUT}/v3_bsc.json"))
        usd_rows = {}
        if os.path.exists(f"{OUT}/valuation_v3.json"):
            vv = json.load(open(f"{OUT}/valuation_v3.json"))
            usd_rows = {r["lp"].lower(): r for r in vv["rows"]}
        for r in v3["records"]:
            bal = int(r["escrowBalance"])
            if bal <= 0:
                continue
            row = usd_rows.get(r["lpToken"].lower(), {})
            tok_usd = row.get("usd", 0) or 0
            total_bal = row.get("escrow_balance")
            share = (bal / int(total_bal)) if total_bal and int(total_bal) > 0 else 0
            usd = tok_usd * share
            v3_total += usd
            if r["lockTime"] <= now:
                v3_ho += usd
            else:
                v3_future += usd
    result["v3"] = {"custody_usd": round(v3_total, 2), "ho_usd": round(v3_ho, 2), "future_usd": round(v3_future, 2)}
    ho += v3_ho; s += v3_future
    result["totals"] = {"E-U_theft": round(eu, 2), "P": round(p, 2), "H-O": round(ho, 2), "S": round(s, 2),
                        "total_measured": round(eu + p + ho + s, 2)}
    json.dump(result, open(f"{OUT}/final_categories.json", "w"), indent=1)
    print(json.dumps(result["totals"], indent=1))
    for l in result["lockers"]:
        print(f"  {l['file']:20s} {l['family']:8s} custody=${l['custody_usd']:>12,.2f} eu_theft=${l['eu_theft_usd']:>10,.2f} ho=${l['ho_usd']:>12,.2f} p=${l['p_usd']:>9,.2f} s=${l['s_usd']:>12,.2f}")
    print("  v3:", result["v3"])
    print(f"  theft candidates >$100: {len(result['theft_candidates'])}")

if __name__ == "__main__":
    main()
