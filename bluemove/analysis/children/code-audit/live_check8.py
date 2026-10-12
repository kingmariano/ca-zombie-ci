#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

q = """{ __type(name: "MoveFunction") { fields { name type { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } }"""
print(json.dumps(gql(q), indent=1)[:1500])

q2 = """query($d: String!) {
  transaction(digest: $d) {
    digest
    kind {
      __typename
      ... on ProgrammableTransaction {
        commands { nodes { __typename ... on MoveCallCommand { function { name module { name package { address } } } } } }
      }
    }
  }
}"""
for dg in ["FhwBTFkyANCyzVEG4F2xyJZeiWHee5STqkciSwvNQH4", "9rjCSkLRWRjxKXLsLiCtWDpPzRzh2zkXSmCBNMYk5k3y", "GkZiR2foL7Ay86ajpyPMYGWf5WgLNDWpxeDjo8AZFWS4"]:
    try:
        r = gql(q2, {"d": dg})
        kind = ((r.get("transaction") or {}).get("kind") or {})
        cmds = (((kind.get("commands") or {}).get("nodes")) or [])
        print("===", dg)
        for c in cmds:
            fn = c.get("function") or {}
            mod = fn.get("module") or {}
            pkg = mod.get("package") or {}
            print("   call:", pkg.get("address"), "::", mod.get("name"), "::", fn.get("name"), c.get("__typename"))
    except Exception as e:
        print("===", dg, "ERR", str(e)[:400])
