#!/usr/bin/env python3
"""Explore Bitquery Solana schema (v2 streaming + v1). Read-only; masks token."""
import json, sys, urllib.request, urllib.error

def load_env(path="/home/heisenberg/CA/.env"):
    env = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env

TOK = load_env().get("BITQUERY_ACCESS_TOKEN", "")
H = {"Content-Type": "application/json", "Authorization": f"Bearer {TOK}"}

def gql(url, query):
    body = json.dumps({"query": query}).encode()
    req = urllib.request.Request(url, data=body, headers=H)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode())
        except Exception: return e.code, {"raw": "unparseable"}

V2 = "https://streaming.bitquery.io/graphql"
query = sys.argv[1] if len(sys.argv) > 1 else """
{
  __type(name: "Solana") { fields { name type { name kind ofType { name kind } } } }
}
"""
st, j = gql(V2, query)
print("HTTP", st)
print(json.dumps(j, indent=1)[:12000])
