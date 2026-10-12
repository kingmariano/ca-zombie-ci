#!/usr/bin/env python3
"""Fetch verified source+ABI for all team-deployed contracts; list function names."""
import json, urllib.request, time

def api(p):
    req = urllib.request.Request("https://promscan.io" + p, headers={"User-Agent": "Mozilla/5.0"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read())

addrs = [h for ts, h, name, hsh in json.load(open("team_deployments.json"))]
addrs += ["0xE48E17f27Dcdf9ad71af6165a0f4690FEB7A87cC"]
sources = {}
for a in addrs:
    if not a:
        continue
    try:
        d = api(f"/api/v2/smart-contracts/{a}")
    except Exception as e:
        print(a, "no contract info", e)
        continue
    name = d.get("name") or d.get("file_path")
    abi = d.get("abi") or []
    fns = []
    for item in abi:
        if item.get("type") == "function":
            fns.append(item.get("name", "?") + "(" + ",".join(i.get("type", "?") for i in item.get("inputs", [])) + ")")
    sc = d.get("source_code") or ""
    sources[a] = {"name": name, "verified": d.get("is_verified"), "fns": fns, "srclen": len(sc)}
    print(f"== {a} {name} verified={d.get('is_verified')} srclen={len(sc)}")
    print("   fns:", sorted(set(fns)))
    if sc:
        json.dump(sc, open(f"/home/heisenberg/CA/savmswap/analysis/src_{a[:10]}.json", "w"), indent=1)
    time.sleep(0.15)
json.dump(sources, open("/home/heisenberg/CA/savmswap/analysis/team_contract_sources.json", "w"), indent=1)
