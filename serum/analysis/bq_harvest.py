#!/usr/bin/env python3
"""Harvest recent Serum v3 instructions from Bitquery (live stream retention).
Extracts market candidates. Read-only, masks token."""
import json, sys, time, urllib.request, urllib.error

def load_env(path="/home/heisenberg/CA/.env"):
    env = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env

TOK = load_env()["BITQUERY_ACCESS_TOKEN"]
H = {"Content-Type": "application/json", "Authorization": f"Bearer {TOK}"}
URL = "https://streaming.bitquery.io/graphql"
PROG = "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin"

MODE = sys.argv[1] if len(sys.argv) > 1 else "close"   # close | all
PAGES = int(sys.argv[2]) if len(sys.argv) > 2 else 10
PAGE = 10000
OUT = f"/home/heisenberg/CA/serum/analysis/bq_harvest_{MODE}.json"

if MODE == "close":
    where = 'Instruction: {Program: {Address: {is: "%s"}}, Data: {is: "000e000000"}}' % PROG
else:
    where = 'Instruction: {Program: {Address: {is: "%s"}}}' % PROG

def gql(query):
    body = json.dumps({"query": query}).encode()
    req = urllib.request.Request(URL, data=body, headers=H)
    try:
        with urllib.request.urlopen(req, timeout=240) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"http_error": e.code, "body": e.read().decode()[:500]}

items = []
for p in range(PAGES):
    q = """
    { Solana { Instructions(
        where: {%s}
        limit: {count: %d, offset: %d}
        orderBy: {ascending: Block_Height}
      ) {
        Block { Height Time }
        Instruction { Data Accounts { Address IsWritable } }
        Transaction { Signature }
      } } }
    """ % (where, PAGE, p * PAGE)
    j = gql(q)
    if "data" not in j or not j["data"]["Solana"]["Instructions"]:
        print("page", p, "empty or error:", json.dumps(j)[:300], flush=True)
        break
    rows = j["data"]["Solana"]["Instructions"]
    items += rows
    print(f"page {p}: +{len(rows)} total {len(items)}", flush=True)
    if len(rows) < PAGE:
        break
    time.sleep(1)

with open(OUT, "w") as f:
    json.dump(items, f)

mkt = {}
owners = {}
times = []
for r in items:
    accts = r["Instruction"].get("Accounts") or []
    if len(accts) >= 4:
        m = accts[3]["Address"]
        mkt.setdefault(m, 0)
        mkt[m] += 1
        if len(accts) >= 2:
            owners.setdefault(accts[1]["Address"], 0)
            owners[accts[1]["Address"]] += 1
    times.append(r["Block"]["Time"])

print("instructions:", len(items))
print("distinct candidate markets:", len(mkt))
print("distinct owner accts:", len(owners))
print("top owners:", sorted(owners.items(), key=lambda kv: -kv[1])[:5])
print("time range:", min(times) if times else None, "->", max(times) if times else None)
json.dump(sorted(mkt), open(f"/home/heisenberg/CA/serum/analysis/bq_markets_{MODE}.json", "w"), indent=1)
