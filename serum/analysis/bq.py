#!/usr/bin/env python3
"""Run a GraphQL query from a file against Bitquery v2; save JSON. Read-only, masks token."""
import json, sys, urllib.request, urllib.error

def load_env(path="/home/heisenberg/CA/.env"):
    env = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env

TOK = load_env()["BITQUERY_ACCESS_TOKEN"]
qfile = sys.argv[1]
outfile = sys.argv[2] if len(sys.argv) > 2 else None
q = open(qfile).read()
req = urllib.request.Request(
    "https://streaming.bitquery.io/graphql",
    data=json.dumps({"query": q}).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOK}"})
try:
    j = json.loads(urllib.request.urlopen(req, timeout=180).read().decode())
except urllib.error.HTTPError as e:
    j = {"http_error": e.code, "body": e.read().decode()[:2000]}
if outfile:
    json.dump(j, open(outfile, "w"), indent=1)
print(json.dumps(j, indent=1)[:6000])
