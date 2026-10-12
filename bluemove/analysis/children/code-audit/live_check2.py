#!/usr/bin/env python3
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql, all_dynamic_fields

DI = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"

# Find VersionManage among Dex_Info dynamic object fields (scan first N pages)
found = []
cursor, pages = None, 0
while True:
    q = """query($addr: SuiAddress!, $after: String) {
      object(address: $addr) {
        dynamicFields(first: 50, after: $after) {
          pageInfo { hasNextPage endCursor }
          nodes {
            name { type { repr } json }
            value { __typename ... on MoveObject { address contents { type { repr } json } } }
          }
        }
      }
    }"""
    d = gql(q, {"addr": DI, "after": cursor})["object"]["dynamicFields"]
    for n in d.get("nodes") or []:
        v = n.get("value") or {}
        trepr = ((v.get("contents") or {}).get("type") or {}).get("repr") or ""
        if "VersionManage" in trepr:
            found.append(n)
    pages += 1
    pi = d.get("pageInfo") or {}
    if not pi.get("hasNextPage") or found or pages >= 3:
        break
    cursor = pi.get("endCursor")
print("=== VersionManage fields found:", len(found))
print(json.dumps(found, indent=1)[:2000])

# Inspect escrow dynamic fields of a couple of live pools
for pool in ["0x32999bec61de990fe4cb931c98221677e91042048b0db773554eb7288a414368",
             "0x2c90e8563e9a058147aa271e4bc4528d788226ed01f6076d2b58c938d1f20359"]:
    q = """query($addr: SuiAddress!) {
      object(address: $addr) {
        dynamicFields(first: 50) {
          nodes {
            name { type { repr } json }
            value { __typename ... on MoveObject { address contents { type { repr } json } } }
          }
        }
      }
    }"""
    d = gql(q, {"addr": pool})["object"]["dynamicFields"]["nodes"]
    print(f"=== pool {pool} dynamic fields:")
    for n in d:
        v = n.get("value") or {}
        trepr = ((v.get("contents") or {}).get("type") or {}).get("repr") or ""
        print("  name:", n["name"]["json"], "| value.type:", trepr, "| json:", json.dumps((v.get("contents") or {}).get("json"))[:300])
