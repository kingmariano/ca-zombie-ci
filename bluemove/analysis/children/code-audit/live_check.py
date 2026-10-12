#!/usr/bin/env python3
"""Read-only live checks (public Sui GraphQL) for BlueMove package mapping + version gate.
Writes only inside this child dir."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql, object_

# 1) Dex_Info object + dynamic fields (VersionManage)
DI = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
q = """query($addr: SuiAddress!) {
  object(address: $addr) {
    version
    digest
    asMoveObject { contents { type { repr } json } }
    dynamicFields(first: 10) {
      pageInfo { hasNextPage endCursor }
      nodes { name { type { repr } json } value { __typename ... on MoveObject { address contents { type { repr } json } } } }
    }
  }
}"""
d = gql(q, {"addr": DI})
print("=== Dex_Info ===")
print(json.dumps(d, indent=1)[:4000])

# 2) packages: module/function inventory
for pkg in ["0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9",
            "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f",
            "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"]:
    q = """query($addr: SuiAddress!) {
      object(address: $addr) {
        version
        digest
        owner { __typename }
        asMovePackage {
          modules(first: 50) {
            nodes {
              name
              functions(first: 100) { nodes { name visibility isEntry } }
            }
          }
        }
      }
    }"""
    try:
        d = gql(q, {"addr": pkg})
        mp = d.get("object") or {}
        print(f"=== package {pkg} obj.version={mp.get('version')} owner={mp.get('owner')}")
        asp = mp.get("asMovePackage") or {}
        mods = (asp.get("modules") or {}).get("nodes") or []
        for m in mods:
            fns = ",".join(f"{f['name']}[{'E' if f['isEntry'] else ''}{f['visibility'][:3]}]" for f in (m["functions"]["nodes"] or []))
            print(f"  {m['name']}: {fns[:1200]}")
    except Exception as e:
        print(f"=== package {pkg} ERROR: {e}")
