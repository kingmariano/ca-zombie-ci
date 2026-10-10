#!/usr/bin/env python3
"""Dump all SuiDex weekly revenue epochs + compute claim accounting vs vault balance."""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from sui_rpc import rpc, get_object

LOCKER = "0xb604843d501173f9ea0762fbaa7cadaea3454c942deb527cb8905861ce39798b"
EPOCHS_TABLE = "0xa52c45789a7c85a5c4b2bd790c9c41fb99f216f046712a527567139d79e12f9c"
SUI_VAULT = "0xd781268befec0270299d5089f182d8c1f1caed15f8b7db3fa1a267b73e89ce9f"

def main():
    out = {"epochs": [], "locker": LOCKER, "epochs_table": EPOCHS_TABLE}
    cursor = None
    while True:
        r = rpc("suix_getDynamicFields", [EPOCHS_TABLE, cursor, 50])
        for it in r["data"]:
            obj = get_object(it["objectId"])
            raw = obj["data"]["content"]["fields"]
            f = raw.get("value", {}).get("fields", raw)  # unwrap dynamic_field::Field{name,value}
            pa = f.get("pool_allocations", {}).get("fields", {}) if isinstance(f.get("pool_allocations"), dict) else {}
            out["epochs"].append({
                "epoch_id": f.get("epoch_id"),
                "week_number": f.get("week_number"),
                "week_start": f.get("week_start_timestamp"),
                "week_end": f.get("week_end_timestamp"),
                "total_sui_revenue": f.get("total_sui_revenue"),
                "alloc": {k: pa.get(k) for k in [
                    "week_pool_sui", "three_month_pool_sui", "year_pool_sui", "three_year_pool_sui",
                    "week_pool_total_staked", "three_month_pool_total_staked",
                    "year_pool_total_staked", "three_year_pool_total_staked"]},
                "claimed": {k: f.get(k) for k in [
                    "week_pool_claimed", "three_month_pool_claimed",
                    "year_pool_claimed", "three_year_pool_claimed"]},
                "is_claimable": f.get("is_claimable"),
                "allocations_finalized": f.get("allocations_finalized"),
            })
        if not r.get("hasNextPage"):
            break
        cursor = r["nextCursor"]
    # vault
    v = get_object(SUI_VAULT)["data"]["content"]["fields"]
    out["sui_vault"] = {"id": SUI_VAULT, "balance": v["sui_balance"], "total_deposited": v["total_deposited"], "total_distributed": v["total_distributed"]}
    with open(os.path.join(os.environ.get("SUIDEX_OUT_DIR", os.path.dirname(__file__)), "epochs_state.json"), "w") as fh:
        json.dump(out, fh, indent=1)

    tot_rev = sum(int(e["total_sui_revenue"] or 0) for e in out["epochs"])
    tot_alloc = 0; tot_claimed = 0; rem_by_pool = {"week": 0, "3m": 0, "year": 0, "3yr": 0}
    keys = ["week_pool_sui", "three_month_pool_sui", "year_pool_sui", "three_year_pool_sui"]
    ck = ["week_pool_claimed", "three_month_pool_claimed", "year_pool_claimed", "three_year_pool_claimed"]
    for e in out["epochs"]:
        for k, c, nm in zip(keys, ck, ["week", "3m", "year", "3yr"]):
            a = int(e["alloc"].get(k) or 0); cl = int(e["claimed"].get(c) or 0)
            tot_alloc += a; tot_claimed += cl
            rem_by_pool[nm] += max(a - cl, 0)
    print(f"epochs={len(out['epochs'])} sum_revenue={tot_rev/1e9:.6f} SUI  sum_alloc={tot_alloc/1e9:.6f}  sum_claimed={tot_claimed/1e9:.6f}")
    print(f"vault balance={int(out['sui_vault']['balance'])/1e9:.6f} deposited={int(out['sui_vault']['total_deposited'])/1e9:.6f} distributed={int(out['sui_vault']['total_distributed'])/1e9:.6f}")
    print("remaining unclaimed by pool (raw):", rem_by_pool)
    rem = sum(rem_by_pool.values())
    print(f"total remaining claimable-in-principle={rem/1e9:.6f} SUI vs vault={int(out['sui_vault']['balance'])/1e9:.6f} SUI")
    now = int(time.time())
    print(f"now={now}  current epoch 35 window: {[(e['epoch_id'], e['week_start'], e['week_end'], e['is_claimable'], e['allocations_finalized']) for e in out['epochs'] if e['epoch_id'] in (34,35)]}")

if __name__ == "__main__":
    main()
