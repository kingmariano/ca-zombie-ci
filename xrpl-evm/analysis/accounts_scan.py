#!/usr/bin/env python3
"""Scan all XRPL EVM accounts for vesting account types (read-only)."""
import json, urllib.request, urllib.parse, collections, sys, time

API = "https://cosmos-api.xrplevm.org"
def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

types = collections.Counter()
vesting = []
key = None
pages = 0
total_seen = 0
while True:
    q = {"pagination.limit": "1000"}
    if key:
        q["pagination.key"] = key
    url = f"{API}/cosmos/auth/v1beta1/accounts?" + urllib.parse.urlencode(q)
    d = get(url)
    accts = d.get("accounts", [])
    for a in accts:
        t = a.get("@type", "?")
        types[t] += 1
        if "Vesting" in t or "vesting" in t:
            vesting.append(a)
    total_seen += len(accts)
    pages += 1
    key = d.get("pagination", {}).get("next_key")
    if not key or pages > 60:
        break
    time.sleep(0.05)

out = {
    "pages": pages,
    "total_accounts_scanned": total_seen,
    "type_histogram": dict(types.most_common()),
    "vesting_accounts_found": len(vesting),
    "vesting_sample": vesting[:5],
}
json.dump(out, open("/home/heisenberg/CA/xrpl-evm/analysis/accounts_scan.json", "w"), indent=2)
print(json.dumps({k: v for k, v in out.items() if k != "vesting_sample"}, indent=2))
