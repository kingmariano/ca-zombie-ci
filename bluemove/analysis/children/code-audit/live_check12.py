#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

q = """query($addr: SuiAddress!) {
  address(address: $addr) {
    transactions(last: 20) {
      nodes { digest kind { __typename } }
    }
  }
}"""
for label, addr in [("dev", "0x049cc391ab4d3503e03dbb24c4f9e28f3cdd2ddf8a459e0d43012c3868ffefa1")]:
    try:
        d = gql(q, {"addr": addr})
        nodes = (((d.get("address") or {}).get("transactions") or {}).get("nodes")) or []
        print(label, len(nodes))
        for n in nodes:
            print("  ", n["digest"], n["kind"]["__typename"] if n.get("kind") else None)
    except Exception as e:
        print(label, "ERR", str(e)[:400])
