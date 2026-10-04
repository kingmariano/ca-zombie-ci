#!/usr/bin/env python3
"""Bitquery probe for Solana Serum program data. Read-only. Masks token."""
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

E = load_env()
TOK = E.get("BITQUERY_ACCESS_TOKEN", "")
if not TOK:
    print("NO BITQUERY TOKEN"); sys.exit(1)

ENDPOINTS = ["https://streaming.bitquery.io/graphql", "https://graphql.bitquery.io"]

def gql(url, query, headers_extra=None):
    body = json.dumps({"query": query}).encode()
    h = {"Content-Type": "application/json"}
    h.update(headers_extra or {})
    req = urllib.request.Request(url, data=body, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode())
        except Exception: return e.code, {"raw": "unparseable"}

INTRO = "{ __schema { queryType { fields { name } } } }"
for url in ENDPOINTS:
    for hname in ("Authorization", "X-API-KEY"):
        hv = f"Bearer {TOK}" if hname == "Authorization" else TOK
        st, j = gql(url, INTRO, {hname: hv})
        msg = json.dumps(j)[:400]
        print(f"{url} [{hname}]: HTTP {st} {msg}", flush=True)
        if st == 200 and "data" in j:
            fields = [f["name"] for f in j["data"]["__schema"]["queryType"]["fields"]]
            print("QUERY FIELDS:", fields[:60], flush=True)
            break
