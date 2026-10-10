#!/usr/bin/env python3
"""Scan SuiDex locker lock tables (read-only) -> locks_state.json.

All active locks across the four lock-period tables (week/3m/year/3yr), including
amount, lock_period, lock_end, stake_timestamp (needed for per-epoch eligibility).
"""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
from sui_rpc import rpc, get_object

LOCKER = "0xb604843d501173f9ea0762fbaa7cadaea3454c942deb527cb8905861ce39798b"
TABLES = {
    "week": "0xe872c5b25849dbe267e5d287480f326a5226b5752ff1484646b80945a733a2f2",
    "3m": "0xe144016d682690aa633c3bb5bb67da5455354d3115a8ede8d95d45e88510d3d1",
    "year": "0xc3932babf1ae9c879c862c55f60a0d2bb10d2a4277feb786ac81220b05cc00db",
    "3yr": "0x5bf84aaea84d2e416467e3bd5f475d8b3dab1d24699fe2e39be659fdbb6217a9",
}

def walk_table(table_id, limit=50):
    cursor = None
    while True:
        r = rpc("suix_getDynamicFields", [table_id, cursor, limit])
        for it in r["data"]:
            yield it
        if not r.get("hasNextPage"):
            break
        cursor = r["nextCursor"]

def parse_locks(field_obj):
    fields = field_obj["data"]["content"]["fields"]
    val = fields.get("value", {})
    out = []
    if isinstance(val, list):
        for lk in val:
            f = lk.get("fields", lk)
            out.append({k: f.get(k) for k in [
                "id", "amount", "lock_period", "lock_end", "stake_timestamp",
                "last_victory_claim_timestamp", "total_victory_claimed",
                "last_sui_epoch_claimed"]})
    return out

def main():
    outdir = os.environ.get("SUIDEX_OUT_DIR", os.path.dirname(__file__))
    locks_out = {"locker": LOCKER, "tables": {}, "users": {}}
    t0 = time.time()
    total = 0
    for period, tid in TABLES.items():
        n = 0
        for it in walk_table(tid):
            user = it["name"]["value"]
            obj = get_object(it["objectId"])
            locks = parse_locks(obj)
            locks_out["users"].setdefault(user, {})[period] = locks
            n += len(locks)
        locks_out["tables"][period] = {"id": tid, "locks": n}
        total += n
        print(f"[locks] {period}: {n} locks  ({time.time()-t0:.0f}s)", flush=True)
    locks_out["total_active_locks"] = total
    with open(os.path.join(outdir, "locks_state.json"), "w") as fh:
        json.dump(locks_out, fh)
    print(f"[locks] total {total} active locks across {len(locks_out['users'])} users, saved. ({time.time()-t0:.0f}s)")

if __name__ == "__main__":
    main()
