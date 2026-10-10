#!/usr/bin/env python3
"""Scan SuiDex locker lock tables + user_epoch_claims tables (read-only).

Outputs:
  analysis/locks_state.json   -> {users: [{user, locks:[{...}]}]}
  analysis/claims_state.json  -> {users: [{user, table_id, claims:[{claim_key_hex, epoch_id, lock_id, sui_claimed, ...}]}]}
"""
import json, sys, os, time, base64
sys.path.insert(0, os.path.dirname(__file__))
from sui_rpc import rpc, get_object

LOCKER = "0xb604843d501173f9ea0762fbaa7cadaea3454c942deb527cb8905861ce39798b"
TABLES = {
    "week": "0xe872c5b25849dbe267e5d287480f326a5226b5752ff1484646b80945a733a2f2",
    "3m": "0xe144016d682690aa633c3bb5bb67da5455354d3115a8ede8d95d45e88510d3d1",
    "year": "0xc3932babf1ae9c879c862c55f60a0d2bb10d2a4277feb786ac81220b05cc00db",
    "3yr": "0x5bf84aaea84d2e416467e3bd5f475d8b3dab1d24699fe2e39be659fdbb6217a9",
}
CLAIMS_TABLE = "0x273b7618bdc10b621e1894121c1cafe456ac3c22b7d9925d445b39bf027325f6"

def walk_table(table_id, limit=50):
    """Yield (name_json, objectId) for every dynamic field of a table."""
    cursor = None
    while True:
        r = rpc("suix_getDynamicFields", [table_id, cursor, limit])
        for it in r["data"]:
            yield it
        if not r.get("hasNextPage"):
            break
        cursor = r["nextCursor"]

def parse_locks(field_obj):
    """Field<address, vector<Lock>> -> list of Lock dicts."""
    fields = field_obj["data"]["content"]["fields"]
    val = fields.get("value", {})
    # value may be raw list of struct dicts
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
    with open(os.path.join(os.path.dirname(__file__), "locks_state.json"), "w") as fh:
        json.dump(locks_out, fh)
    print(f"[locks] total {total} active locks across {len(locks_out['users'])} users, saved. ({time.time()-t0:.0f}s)")

    # claims
    claims_out = {"table": CLAIMS_TABLE, "users": []}
    nrec = 0
    for it in walk_table(CLAIMS_TABLE):
        user = it["name"]["value"]
        obj = get_object(it["objectId"])
        fields = obj["data"]["content"]["fields"]
        val = fields.get("value", {})
        sub_table = None
        if isinstance(val, dict):
            sub_table = val.get("fields", {}).get("id", {}).get("id")
        recs = []
        if sub_table:
            for cit in walk_table(sub_table, limit=100):
                cobj = get_object(cit["objectId"])
                cf = cobj["data"]["content"]["fields"]
                cv = cf.get("value", {}).get("fields", {})
                recs.append({
                    "name_bcs": cit.get("bcsName"),
                    "epoch_id": cv.get("epoch_id"),
                    "lock_id": cv.get("lock_id"),
                    "lock_period": cv.get("lock_period"),
                    "pool_type": cv.get("pool_type"),
                    "amount_staked": cv.get("amount_staked"),
                    "sui_claimed": cv.get("sui_claimed"),
                    "claim_timestamp": cv.get("claim_timestamp"),
                })
        claims_out["users"].append({"user": user, "table_id": sub_table, "claims": recs})
        nrec += len(recs)
        print(f"[claims] {user[:12]}.. {len(recs)} records ({time.time()-t0:.0f}s)", flush=True)
    claims_out["total_records"] = nrec
    with open(os.path.join(os.path.dirname(__file__), "claims_state.json"), "w") as fh:
        json.dump(claims_out, fh)
    print(f"[claims] total {nrec} claim records across {len(claims_out['users'])} users, saved. ({time.time()-t0:.0f}s)")

if __name__ == "__main__":
    main()
