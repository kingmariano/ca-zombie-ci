#!/usr/bin/env python3
"""For each live Socket route impl/controller, locate the deployed contract's own source file
(by ContractName), extract it, and report external call / transferFrom patterns with context.
"""
import json, os, glob, re

HERE = os.path.dirname(os.path.abspath(__file__))
meta = json.load(open(os.path.join(HERE, "socket_impls.json")))
scan = json.load(open(os.path.join(HERE, "socket_routes_26108903.json")))
route_of = {}
for i, a in scan["routes"].items():
    if a in meta:
        route_of.setdefault(a, []).append(i)
for i, a in scan["controllers"].items():
    if a in meta:
        route_of.setdefault(a, []).append("c" + i)

out = {}
for addr, m in meta.items():
    name = m.get("name")
    f = os.path.join(HERE, "socket_impls", f"{addr}_{name}.json")
    if not os.path.exists(f):
        out[addr] = {"name": name, "note": "no source json"}
        continue
    raw = open(f).read()
    try:
        if raw.startswith("{{"):
            raw = raw.strip()[1:-1]
        j = json.loads(raw)
    except Exception as e:
        out[addr] = {"name": name, "note": "unparseable " + str(e)[:60]}
        continue
    files = j.get("sources") or {}
    main_file = None
    main_content = ""
    for fn, c in files.items():
        content = c.get("content", "") if isinstance(c, dict) else ""
        if re.search(r"\bcontract\s+" + re.escape(name or "###") + r"\b", content):
            main_file, main_content = fn, content
            break
    hits = []
    if main_content:
        for mm in re.finditer(r"([^\n]*\.call[^\n]*)", main_content):
            line = mm.group(1).strip()
            if "delegatecall" not in line:
                hits.append(line[:220])
        for mm in re.finditer(r"([^\n]*safeTransferFrom[^\n]*)", main_content):
            hits.append(mm.group(1).strip()[:220])
    out[addr] = {"name": name, "main_file": main_file, "routes": route_of.get(addr, []),
                 "hits": hits[:40]}
    print("=" * 100)
    print(addr, name, "routes", route_of.get(addr, []), "|", main_file)
    for h in hits[:20]:
        print("   ", h)

json.dump(out, open(os.path.join(HERE, "socket_impl_callsites.json"), "w"), indent=1)
