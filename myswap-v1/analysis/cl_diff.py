"""Diff CL class ABI pre-hack (0x8fade1a3) vs post-patch (0x40974d74); find the upgrade tx."""
import json
from starknet_nodep import rpc, call, call_sel, sel, norm, block_number

CL = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
OLD_CLASS = "0x8fade1a36f2bfcaa55b53c96dfb615e8e60110b87765cf449d09b6e0397b17"
NEW_CLASS = "0x40974d74561db5f6c5e66cb50989cfdfc0ec0d1a96b577f85f29695c769a7bd"

def fns_of(class_hash):
    cls = rpc("starknet_getClass", {"block_id": "latest", "class_hash": class_hash})
    abi = cls.get("abi")
    abi = json.loads(abi) if isinstance(abi, str) else abi
    fns = {}
    for it in abi:
        if it.get("type") == "interface":
            for f in it.get("items", []):
                if f.get("type") == "function":
                    fns[f["name"]] = f
        elif it.get("type") == "function":
            fns[it["name"]] = it
    return fns

old = fns_of(OLD_CLASS)
new = fns_of(NEW_CLASS)
print("old fn count", len(old), "new fn count", len(new))
print("added:", sorted(set(new) - set(old)))
print("removed:", sorted(set(old) - set(new)))
print()
for n in sorted(set(new) - set(old)):
    print("NEW:", n, json.dumps(new[n])[:300])
for n in sorted(set(old) - set(new)):
    print("OLD:", n, json.dumps(old[n])[:300])
print()
for n in ["upgrade", "set_migrator", "migrate_storage", "create_pool", "create_and_initialize_pool", "owner"]:
    if n in new:
        print("both-have", n, json.dumps(new[n])[:200])

# find upgrade events on CL after hack block
print()
try:
    ev = rpc("starknet_getEvents", {
        "filter": {
            "from_block": {"block_number": 10951100},
            "to_block": {"block_number": 11200000},
            "address": norm(CL),
            "chunk_size": 50,
        }
    })
    evs = ev.get("events", [])
    print("events on CL between hack and +250k blocks:", len(evs))
    from collections import Counter
    c = Counter(e["keys"][0] for e in evs if e.get("keys"))
    for k, v in c.most_common(10):
        print(" key", k, v)
    # Upgraded selector candidates
    for cand in ["Upgraded", "upgrade"]:
        print(cand, "->", sel(cand))
except Exception as e:
    print("getEvents ERR", str(e)[:200])
