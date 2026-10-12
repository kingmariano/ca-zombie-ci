#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

print(json.dumps(gql("{ __type(name: \"Address\") { fields { name args { name } type { kind name ofType { kind name } } } } }"), indent=1)[:2500])

# try filtered objects
q = """query($addr: SuiAddress!, $type: String) {
  address(address: $addr) {
    objects(first: 20, filter: { type: $type }) {
      nodes { address contents { type { repr } json } }
    }
  }
}"""
try:
    d = gql(q, {"addr": "0x049cc391ab4d3503e03dbb24c4f9e28f3cdd2ddf8a459e0d43012c3868ffefa1",
                "type": "0x0000000000000000000000000000000000000000000000000000000000000002::package::UpgradeCap"})
    print(json.dumps(d, indent=1)[:3000])
except Exception as e:
    print("filtered err:", str(e)[:400])
