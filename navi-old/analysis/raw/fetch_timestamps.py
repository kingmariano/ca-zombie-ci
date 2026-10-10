#!/usr/bin/env python3
"""Fetch last-modified timestamps for a list of object addresses, batched."""
import json, subprocess, time, sys

funds = json.load(open("funds_merged.json"))
parents = [
    "0x62982dad27fb10bb314b3384d5de8d2ac2d72ab2dbeae5d801dbdb9efa816c80",
    "0xf87a8acb8b81d14307894d12595541a73f19933f88e1326d5be349c7a6f7559c",
]
addrs = [f["address"] for f in funds] + parents
out = {}
BATCH = 8
for s in range(0, len(addrs), BATCH):
    batch = addrs[s:s+BATCH]
    parts = []
    for i, a in enumerate(batch):
        parts.append(f'o{i}: object(address: "{a}") {{ version previousTransaction {{ effects {{ timestamp }} }} }}')
    q = "{ " + " ".join(parts) + " }"
    body = json.dumps({"query": q})
    r = subprocess.run(["./gql.sh"], input=body, capture_output=True, text=True)
    try:
        resp = json.loads(r.stdout)
    except Exception:
        print("BAD:", r.stdout[:200], file=sys.stderr); sys.exit(1)
    if "errors" in resp:
        print("ERR:", json.dumps(resp["errors"])[:200], file=sys.stderr)
    for i, a in enumerate(batch):
        d = resp["data"].get(f"o{i}")
        if d:
            out[a] = {"version": d["version"], "last_modified": d["previousTransaction"]["effects"]["timestamp"]}
    time.sleep(0.5)
json.dump(out, open("fund_timestamps.json", "w"), indent=1)
for a, v in out.items():
    print(a, v["version"], v["last_modified"])
