#!/usr/bin/env python3
"""Fast scan of SuiDex user_epoch_claims sub-tables: decode claim keys from dynamic-field NAMES.

Each claim record field name = u128 key = (epoch_id << 64) | lock_id (create_claim_key in source).
So the *existence* of a field for (user, epoch, lock) == already claimed; no need to fetch contents.
Outputs analysis/claims_keys.json: {users:[{user, table_id, keys:[{epoch_id, lock_id, key_hex}]}], total}
"""
import json, sys, os, time, base64
sys.path.insert(0, os.path.dirname(__file__))
from sui_rpc import rpc, get_object

CLAIMS_TABLE = "0x273b7618bdc10b621e1894121c1cafe456ac3c22b7d9925d445b39bf027325f6"

def walk_table(table_id, limit=100):
    cursor = None
    while True:
        r = rpc("suix_getDynamicFields", [table_id, cursor, limit])
        for it in r["data"]:
            yield it
        if not r.get("hasNextPage"):
            break
        cursor = r["nextCursor"]

def decode_key(b64name):
    raw = base64.b64decode(b64name)
    v = int.from_bytes(raw[:16], "little")
    return v, v >> 64, v & ((1 << 64) - 1)

def main():
    out = {"table": CLAIMS_TABLE, "users": [], "total": 0}
    t0 = time.time()
    for it in walk_table(CLAIMS_TABLE):
        user = it["name"]["value"]
        obj = get_object(it["objectId"])
        fields = obj["data"]["content"]["fields"]
        val = fields.get("value", {})
        sub = val.get("fields", {}).get("id", {}).get("id") if isinstance(val, dict) else None
        keys = []
        if sub:
            for cit in walk_table(sub):
                v, ep, lid = decode_key(cit["bcsName"])
                keys.append({"epoch_id": ep, "lock_id": lid, "key_hex": hex(v)})
        out["users"].append({"user": user, "table_id": sub, "keys": keys})
        out["total"] += len(keys)
        print(f"[claims] {user[:12]}.. {len(keys)} keys ({time.time()-t0:.0f}s)", flush=True)
    with open(os.path.join(os.environ.get("SUIDEX_OUT_DIR", os.path.dirname(__file__)), "claims_keys.json"), "w") as fh:
        json.dump(out, fh)
    print(f"[claims] total {out['total']} claim keys across {len(out['users'])} users ({time.time()-t0:.0f}s)")

if __name__ == "__main__":
    main()
