#!/usr/bin/env python3
"""Re-fetch all funds fresh: version, balance, coin_type, last-modified timestamp."""
import json, subprocess, time, sys

funds = json.load(open("funds_merged.json"))
addrs = [f["address"] for f in funds]
out = {}
BATCH = 6
for s in range(0, len(addrs), BATCH):
    batch = addrs[s:s+BATCH]
    parts = []
    for i, a in enumerate(batch):
        parts.append(
            f'o{i}: object(address: "{a}") {{ version asMoveObject {{ contents {{ type {{ repr }} json }} }} previousTransaction {{ effects {{ timestamp }} }} }}'
        )
    q = "{ " + " ".join(parts) + " }"
    r = subprocess.run(["./gql.sh"], input=json.dumps({"query": q}), capture_output=True, text=True)
    resp = json.loads(r.stdout)
    if "errors" in resp:
        print("ERR batch", s, json.dumps(resp["errors"])[:200], file=sys.stderr)
    for i, a in enumerate(batch):
        d = resp["data"].get(f"o{i}")
        if d and d.get("asMoveObject"):
            j = d["asMoveObject"]["contents"]["json"]
            out[a] = {
                "version": str(d["version"]),
                "coin_type": j["coin_type"],
                "raw_balance": j["balance"],
                "last_modified": d["previousTransaction"]["effects"]["timestamp"],
            }
    time.sleep(0.5)
json.dump(out, open("funds_fresh.json", "w"), indent=1)
print("fetched", len(out), "of", len(addrs))
for f in funds:
    a = f["address"]
    fr = out.get(a, {})
    if fr.get("raw_balance") != f["raw_balance"]:
        print("CHANGED", a, f["raw_balance"], "->", fr.get("raw_balance"))
