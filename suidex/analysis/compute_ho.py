#!/usr/bin/env python3
"""Compute H-O (claimable by active eligible lock holders) vs S (no eligible active lock left)
for the remaining 710.223121 SUI in the SuiDex SUIRewardVault.

Inputs: analysis/{locks_state,claims_keys,epochs_state}.json
Model (from source, verified live):
  share(user,lock,e,p) = floor(lock.amount * pool_sui(e,p) / pool_total_staked(e,p))
  eligibility: lock_period==p, stake_timestamp < week_start(e), lock_end >= week_end(e),
               (user,e,lock.id) not in claims_keys
  H-O(e,p) = min(sum shares of eligible unclaimed active locks, remaining(e,p))
"""
import json, os, sys

HERE = os.environ.get("SUIDEX_OUT_DIR", os.path.dirname(__file__))
PERIODS = {7: "week_pool_sui", 90: "three_month_pool_sui", 365: "year_pool_sui", 1095: "three_year_pool_sui"}
STAKED = {7: "week_pool_total_staked", 90: "three_month_pool_total_staked", 365: "year_pool_total_staked", 1095: "three_year_pool_total_staked"}
CLAIMED = {7: "week_pool_claimed", 90: "three_month_pool_claimed", 365: "year_pool_claimed", 1095: "three_year_pool_claimed"}

def main():
    locks = json.load(open(os.path.join(HERE, "locks_state.json")))
    claims = json.load(open(os.path.join(HERE, "claims_keys.json")))
    epochs = json.load(open(os.path.join(HERE, "epochs_state.json")))

    claimed_set = set()
    for u in claims["users"]:
        ua = u["user"].lower()
        for k in u["keys"]:
            claimed_set.add((ua, int(k["epoch_id"]), int(k["lock_id"])))
    print("claimed (user,epoch,lock) tuples:", len(claimed_set))

    # active locks list
    active = []
    for user, per in locks["users"].items():
        ua = user.lower()
        for period, lks in per.items():
            for lk in lks:
                active.append({
                    "user": ua, "lock_id": int(lk["id"]), "amount": int(lk["amount"]),
                    "lock_period": int(lk["lock_period"]), "lock_end": int(lk["lock_end"]),
                    "stake_timestamp": int(lk["stake_timestamp"]),
                })
    print("active locks:", len(active))

    rows = []
    ho_total = 0
    rem_total = 0
    for e in epochs["epochs"]:
        eid = int(e["epoch_id"])
        ws = int(e["week_start"] or 0); we = int(e["week_end"] or 0)
        if ws == 0:
            continue
        for p, alloc_key in PERIODS.items():
            pool_sui = int(e["alloc"].get(alloc_key) or 0)
            pool_staked = int(e["alloc"].get(STAKED[p]) or 0)
            claimed_amt = int(e["claimed"].get(CLAIMED[p]) or 0)
            remaining = pool_sui - claimed_amt
            if remaining <= 0:
                continue
            rem_total += remaining
            shares = 0; n_elig = 0
            if pool_staked > 0:
                for lk in active:
                    if lk["lock_period"] != p:
                        continue
                    if not (lk["stake_timestamp"] < ws and lk["lock_end"] >= we):
                        continue
                    if (lk["user"], eid, lk["lock_id"]) in claimed_set:
                        continue
                    sh = (lk["amount"] * pool_sui) // pool_staked
                    if sh > 0:
                        shares += sh; n_elig += 1
            ho = min(shares, remaining)
            ho_total += ho
            rows.append((eid, p, pool_sui, claimed_amt, remaining, n_elig, shares, ho))
    print(f"{'epoch':>5} {'pool':>5} {'pool_sui':>12} {'claimed':>12} {'remain':>12} {'elig':>5} {'shares':>12} {'H-O':>12}")
    for r in sorted(rows):
        print(f"{r[0]:>5} {r[1]:>5} {r[2]:>12} {r[3]:>12} {r[4]:>12} {r[5]:>5} {r[6]:>12} {r[7]:>12}")
    print()
    print(f"sum remaining        = {rem_total} MIST = {rem_total/1e9:.9f} SUI")
    print(f"sum H-O (claimable)  = {ho_total} MIST = {ho_total/1e9:.9f} SUI")
    print(f"stuck (S) portion    = {(rem_total-ho_total)} MIST = {(rem_total-ho_total)/1e9:.9f} SUI")
    out = {"remaining_mist": rem_total, "ho_mist": ho_total, "stuck_mist": rem_total-ho_total,
           "rows": [{"epoch": r[0], "pool_days": r[1], "pool_sui": r[2], "claimed": r[3], "remaining": r[4],
                     "eligible_unclaimed_locks": r[5], "sum_shares": r[6], "ho": r[7]} for r in sorted(rows)]}
    json.dump(out, open(os.path.join(HERE, "ho_split.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
