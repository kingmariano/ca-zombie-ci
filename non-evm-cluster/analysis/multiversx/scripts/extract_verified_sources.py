#!/usr/bin/env python3
"""Extract verified source files from raw/verification/*.json into raw/sources_verified/<name>/."""
import base64, json, os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")
VDIR = os.path.join(RAW, "verification")
OUT = os.path.join(RAW, "sources_verified")
summary = json.load(open(os.path.join(RAW, "verification_summary.json")))

def safe(p):
    return p.replace("..", "__")

count = 0
for addr, meta in summary.items():
    f = os.path.join(VDIR, addr + ".json")
    if not os.path.exists(f):
        continue
    d = json.load(open(f))
    if not d.get("source"):
        continue
    contract = d["source"].get("contract") or {}
    entries = contract.get("entries") or []
    if not entries:
        continue
    name = meta.get("name") or addr
    dest = os.path.join(OUT, name)
    for e in entries:
        path = safe(e.get("path", "unknown"))
        content = e.get("content", "")
        try:
            data = base64.b64decode(content)
        except Exception:
            data = content.encode()
        fp = os.path.join(dest, path)
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        with open(fp, "wb") as fh:
            fh.write(data)
        count += 1
    print(f"{name:42s} extracted {len(entries)} files -> {dest}")

print("total files:", count)
