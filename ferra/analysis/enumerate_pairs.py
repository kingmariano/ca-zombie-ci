#!/usr/bin/env python3
"""Enumerate Ferra DLMM pairs: dynamic fields -> pair ids -> live state. Public RPC only."""
import sys, json, time
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, "/home/heisenberg/CA/ferra/analysis")
from sui import rpc

TABLE = "0xd855d2ec282f39dd1cf12feb3a06b76a118ee7c11dd9e37d047973fa0ae5e54b"

def get_df(name):
    for attempt in range(4):
        try:
            r = rpc("suix_getDynamicFieldObject", [TABLE, {"type": "0x2::object::ID", "value": name}])
            f = r["data"]["content"]["fields"]["value"]["fields"]
            return {"key": name, "pair_id": f.get("pair_id"), "pair_key": f.get("pair_key"),
                    "bin_step": f.get("bin_step"),
                    "coin_a": (f.get("coin_type_a") or {}).get("fields", {}).get("name"),
                    "coin_b": (f.get("coin_type_b") or {}).get("fields", {}).get("name")}
        except Exception as e:
            if attempt == 3:
                return {"key": name, "error": str(e)[:200]}
            time.sleep(1 + attempt)

def main():
    df = json.load(open("/home/heisenberg/CA/ferra/analysis/pairs_dynamic_fields.json"))
    names = [e["name"]["value"] for e in df]
    print("fields:", len(names))
    out = []
    with ThreadPoolExecutor(max_workers=8) as ex:
        for i, r in enumerate(ex.map(get_df, names)):
            out.append(r)
            if (i + 1) % 50 == 0: print("fetched", i + 1)
    json.dump(out, open("/home/heisenberg/CA/ferra/analysis/pairs_meta.json", "w"), indent=1)
    ok = [p for p in out if p.get("pair_id")]
    print("pairs with id:", len(ok), "errors:", len(out) - len(ok))

    # fetch pair objects in batches
    ids = [p["pair_id"] for p in ok]
    states = {}
    for i in range(0, len(ids), 50):
        batch = ids[i:i+50]
        r = rpc("sui_multiGetObjects", [batch, {"showType": True, "showContent": True, "showOwner": True}])
        for o in r:
            d = o.get("data") or {}
            states[d.get("objectId")] = d
        print("batch", i, "done")
        time.sleep(0.3)
    json.dump(states, open("/home/heisenberg/CA/ferra/analysis/pairs_state_raw.json", "w"), indent=1)
    print("state objects:", len(states))

if __name__ == "__main__":
    main()
