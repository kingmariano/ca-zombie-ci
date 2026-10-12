#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

VM = "0x41d5f1c14825d92c93cdae3508705cc31582c8aaaca501aaa4970054fd3b5b2d"
q = """query($addr: SuiAddress!) {
  object(address: $addr) {
    previousTransaction { digest }
  }
}"""
d = gql(q, {"addr": VM})
print(json.dumps(d, indent=1)[:800])
prev = (((d.get("object") or {}).get("previousTransaction")) or {}).get("digest")
if prev:
    q2 = """query($d: String!) {
      transaction(digest: $d) {
        digest
        effects { status }
        kind {
          __typename
          ... on ProgrammableTransaction {
            inputs { __typename ... on MoveValue { json moveType { repr } } }
            commands { nodes { __typename ... on MoveCallCommand { function { name module { name package { address } } } } } }
          }
        }
      }
    }"""
    d2 = gql(q2, {"d": prev})
    print(json.dumps(d2, indent=1)[:4000])
