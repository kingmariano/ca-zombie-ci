#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

q = """query($addr: SuiAddress!) {
  address(address: $addr) {
    objects(first: 50) {
      nodes {
        address
        contents { type { repr } json }
      }
    }
  }
}"""
for label, addr in [("dev", "0x049cc391ab4d3503e03dbb24c4f9e28f3cdd2ddf8a459e0d43012c3868ffefa1"),
                    ("fee_to", "0x85bf745a737a34bf73f360c22d5c8aea1f1767f3c458f5269a7c2f821b9d3781")]:
    try:
        d = gql(q, {"addr": addr})
        nodes = (((d.get("address") or {}).get("objects") or {}).get("nodes")) or []
        print(f"=== {label} {addr}: {len(nodes)} objects")
        for n in nodes:
            t = ((n.get("contents") or {}).get("type") or {}).get("repr") or ""
            if "UpgradeCap" in t or "Package" in t or "VersionManage" in t or "Dex" in t:
                print("  ", n.get("address"), t, json.dumps((n.get("contents") or {}).get("json"))[:400])
        # also print type histogram
        from collections import Counter
        c = Counter(((n.get("contents") or {}).get("type") or {}).get("repr") for n in nodes)
        print("  type histogram:", c.most_common(10))
    except Exception as e:
        print(f"{label} ERR", str(e)[:400])
