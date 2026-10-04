#!/usr/bin/env python3
"""Dune API probe for Solana account/instruction tables. Read-only. Masks secrets."""
import json, sys, time, urllib.request, urllib.error, os

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
KEY = E.get("DUNE_API_KEY", "")
if not KEY:
    print("NO DUNE KEY"); sys.exit(1)
H = {"X-Dune-API-Key": KEY, "Content-Type": "application/json"}

def api(method, url, body=None, timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=H, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode())
        except Exception: return e.code, {"raw": "unparseable"}

SQL = sys.argv[1] if len(sys.argv) > 1 else \
    "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema LIKE '%solana%' ORDER BY 1,2 LIMIT 500"

st, j = api("POST", "https://api.dune.com/api/v1/query", {"name": "zombie_h22_probe", "query_sql": SQL, "is_private": True})
print("create:", st, {k: j.get(k) for k in ("query_id", "error", "message")}, flush=True)
if st >= 300 or "query_id" not in j:
    sys.exit(1)
qid = j["query_id"]
st, j = api("POST", f"https://api.dune.com/api/v1/query/{qid}/execute", {})
print("execute:", st, {k: j.get(k) for k in ("execution_id", "error", "message")}, flush=True)
if st >= 300 or "execution_id" not in j:
    sys.exit(1)
eid = j["execution_id"]
state = None
for i in range(60):
    time.sleep(4)
    st, j = api("GET", f"https://api.dune.com/api/v1/execution/{eid}/status")
    state = j.get("state")
    if state in ("QUERY_STATE_COMPLETED", "QUERY_STATE_FAILED", "QUERY_STATE_CANCELLED", "QUERY_STATE_EXPIRED"):
        break
print("status:", state, flush=True)
st, j = api("GET", f"https://api.dune.com/api/v1/execution/{eid}/results?limit=500")
print("results http:", st, flush=True)
res = j.get("result", {})
rows = res.get("rows", []) if isinstance(res, dict) else []
print("rows:", len(rows))
print(json.dumps(rows, default=str)[:8000])
with open("/home/heisenberg/CA/serum/analysis/dune_last_result.json", "w") as f:
    json.dump(j, f, indent=1, default=str)
print("execution_id:", eid)
