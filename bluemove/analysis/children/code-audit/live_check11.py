#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

q = """query($addr: SuiAddress!, $type: String) {
  address(address: $addr) {
    objects(first: 20, filter: { type: $type }) {
      nodes { address contents { type { repr } json } }
    }
  }
}"""
# sanity check filter with SUI coin type
for addr, t, label in [
    ("0x049cc391ab4d3503e03dbb24c4f9e28f3cdd2ddf8a459e0d43012c3868ffefa1",
     "0x0000000000000000000000000000000000000000000000000000000000000002::coin::Coin<0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI>", "dev SUI coin?"),
    ("0x85bf745a737a34bf73f360c22d5c8aea1f1767f3c458f5269a7c2f821b9d3781",
     "0x0000000000000000000000000000000000000000000000000000000000000002::coin::Coin<0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI>", "fee_to SUI coin?"),
]:
    try:
        d = gql(q, {"addr": addr, "type": t})
        nodes = ((d.get("address") or {}).get("objects") or {}).get("nodes") or []
        print(label, len(nodes), json.dumps(nodes)[:300])
    except Exception as e:
        print(label, "ERR", str(e)[:200])

# search UpgradeCap on candidate addresses
caps = ["0x9c8c8293866415a0b631a87e7b2ff960c65c9a497945df83827dfacb69627123",
        "0x97a745334d470988140336826a83ec47a44714635e376ca705bbf10381223213",
        "0x5e99f037c9dc2158925d8db3f5331d8d16024ec650ee2b870cc432af5e2231bd",
        "0x95d659964cdf8f4740d1c3be1404b789543fb69629e53ec63c97cbab394325c1",
        "0xa67511f039c3f45a1c716460a2f496f113bdb896ac2b10d007245d8ab6b5930b"]
for c in caps:
    try:
        d = gql(q, {"addr": c, "type": "0x0000000000000000000000000000000000000000000000000000000000000002::package::UpgradeCap"})
        nodes = ((d.get("address") or {}).get("objects") or {}).get("nodes") or []
        print("cap?", c[:10], len(nodes), json.dumps(nodes)[:500])
    except Exception as e:
        print("cap?", c[:10], "ERR", str(e)[:200])
