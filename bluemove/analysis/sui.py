#!/usr/bin/env python3
"""Shared Sui GraphQL helper for BlueMove Phase-2 (read-only, public endpoints only).

No API keys, no secrets. Uses public Sui GraphQL: https://graphql.mainnet.sui.io/graphql
JSON-RPC on public fullnodes is deprecated (method-not-found as of 2026-10-12).
"""
import json, time, sys, urllib.request

GQL = "https://graphql.mainnet.sui.io/graphql"
UA = {"User-Agent": "Mozilla/5.0 (research; bluemove-phase2)", "Content-Type": "application/json"}

def gql(query, variables=None, timeout=60, retries=4):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(GQL, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read())
            if d.get("errors"):
                last = d["errors"]
                # retry on rate limits / transient
                if any("rate" in str(e).lower() or "timeout" in str(e).lower() for e in d["errors"]):
                    time.sleep(2 * (i + 1)); continue
                raise RuntimeError(json.dumps(d["errors"])[:500])
            return d.get("data")
        except Exception as e:
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"gql failed: {last}")

def latest_checkpoint():
    d = gql("{ checkpoint { sequenceNumber timestamp } }")
    return d["checkpoint"]

def object_(addr, extra=""):
    q = """query($addr: SuiAddress!) {
      object(address: $addr) {
        address
        version
        digest
        owner { __typename ... on AddressOwner { address { address } } }
        asMoveObject { contents { type { repr } json } }
        %s
      }
    }""" % extra
    return gql(q, {"addr": addr})["object"]

def dynamic_fields(parent, first=50, after=None, want_json=True):
    q = """query($addr: SuiAddress!, $after: String) {
      object(address: $addr) {
        dynamicFields(first: %d, after: $after) {
          pageInfo { hasNextPage endCursor }
          nodes {
            name { type { repr } json }
            value { __typename ... on MoveObject { address contents { type { repr } json } } }
          }
        }
      }
    }""" % first
    return gql(q, {"addr": parent, "after": after})["object"]["dynamicFields"]

def all_dynamic_fields(parent, first=50, cap=None, progress=None):
    out, cursor, pages = [], None, 0
    while True:
        df = dynamic_fields(parent, first=first, after=cursor)
        for n in df.get("nodes") or []:
            out.append(n)
        pages += 1
        if progress and pages % 20 == 0:
            print(f"  ...{len(out)} fields, page {pages}", file=sys.stderr)
        pi = df.get("pageInfo") or {}
        if not pi.get("hasNextPage"):
            break
        cursor = pi.get("endCursor")
        if cap and len(out) >= cap:
            break
        time.sleep(0.05)
    return out

if __name__ == "__main__":
    print(json.dumps(latest_checkpoint(), indent=1))
