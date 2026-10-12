#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

for pkg in ["0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9",
            "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f",
            "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"]:
    q = """query($addr: SuiAddress!) {
      object(address: $addr) {
        version
        digest
        asMovePackage {
          modules(first: 50) {
            nodes {
              name
              functions(first: 50) { nodes { name visibility isEntry } }
            }
          }
        }
      }
    }"""
    try:
        d = gql(q, {"addr": pkg})
    except Exception as e:
        print(f"=== package {pkg} ERROR: {str(e)[:300]}")
        continue
    mp = d.get("object") or {}
    print(f"=== package {pkg} obj.version={mp.get('version')} digest={mp.get('digest')}")
    asp = mp.get("asMovePackage") or {}
    mods = (asp.get("modules") or {}).get("nodes") or []
    for m in mods:
        fns = m.get("functions", {}).get("nodes") or []
        names = ",".join(f"{f['name']}{'*' if f['isEntry'] else ''}" for f in fns)
        print(f"  {m['name']}: {names}")
