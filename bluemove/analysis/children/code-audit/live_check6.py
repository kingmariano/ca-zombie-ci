#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

for dg in ["FhwBTFkyANCyzVEG4F2xyJZeiWHee5STqkciSwvNQH4", "9rjCSkLRWRjxKXLsLiCtWDpPzRzh2zkXSmCBNMYk5k3y"]:
    q = """query($d: String!) {
      transaction(digest: $d) {
        digest
        kind {
          __typename
          ... on ProgrammableTransaction {
            inputs { __typename }
            commands {
              __typename
              ... on MoveCall { package { address } module function }
            }
          }
        }
      }
    }"""
    try:
        r = gql(q, {"d": dg})
        print("===", dg)
        print(json.dumps(r, indent=1)[:3500])
    except Exception as e:
        print("===", dg, "ERR", str(e)[:500])
