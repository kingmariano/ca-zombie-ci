#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

STABLE = "0x5a7eca40df453efe6bb1feae99e5b8fc072d1252cbd1979eb187d625dc9b47c9"
q = """query($addr: SuiAddress!) {
  object(address: $addr) {
    version
    digest
    asMoveObject { contents { type { repr } json } }
    dynamicFields(first: 10) {
      nodes {
        name { type { repr } json }
        value { __typename ... on MoveObject { address contents { type { repr } json } } }
      }
    }
  }
}"""
d = gql(q, {"addr": STABLE})
print(json.dumps(d, indent=1)[:4000])
