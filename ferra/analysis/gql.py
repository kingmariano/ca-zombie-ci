#!/usr/bin/env python3
"""Minimal Sui GraphQL client (official endpoint, no key)."""
import json, sys, urllib.request

URL = "https://graphql.mainnet.sui.io/graphql"

def gql(query, variables=None):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json", "User-Agent": "ferra-reverify/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        j = json.loads(r.read().decode())
    if "errors" in j:
        raise RuntimeError(json.dumps(j["errors"])[:1000])
    return j["data"]

if __name__ == "__main__":
    q = sys.argv[1] if len(sys.argv) > 1 else "{ chainIdentifier }"
    print(json.dumps(gql(q), indent=1)[:8000])
